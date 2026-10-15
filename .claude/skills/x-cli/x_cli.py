#!/usr/bin/env python3
"""Read X/Twitter from the CLI as a logged-in user, browserless, no dev app.

Auth = the logged-in cookie (auth_token + ct0) + the public web Bearer; ct0 is sent as the
x-csrf-token header. Transport = curl_cffi Chrome TLS impersonation (X blocks non-browser
fingerprints). Data comes from X's internal GraphQL API; the per-operation queryIds are
resolved from X's JS bundles at runtime and cached by build hash (self-healing across deploys),
and missing `features` flags are auto-negotiated from X's own error messages.

Output is optimized for an LLM reader: compact text by default, `--json` for a stable schema
(the contract for a digest layer). Importable: build an XClient, then fetch_* functions.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.parse
from email.utils import parsedate_to_datetime
from pathlib import Path

CONFIG_DIR = Path(os.path.expanduser("~/.config/x-cli"))
CONFIG_PATH = CONFIG_DIR / "config.json"
QUERYIDS_PATH = CONFIG_DIR / "queryids.json"
BASE_API = "https://x.com/i/api/graphql"
PUBLIC_BEARER = ("AAAAAAAAAAAAAAAAAAAAANRILgAAAAAAnNwIzUejRCOuH5E6I8xnZz4puTs="
                 "1Zv7ttfk8LF81IUq16cHjhLTvJu4FA33AGWWjCpTnA")
DEFAULT_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")
OPS_NEEDED = ["Viewer", "UserByScreenName", "UserTweets", "UserTweetsAndReplies",
              "HomeTimeline", "HomeLatestTimeline", "TweetDetail", "SearchTimeline"]


class XError(RuntimeError):
    pass


def _die(msg, code=1):
    print(msg, file=sys.stderr)
    raise SystemExit(code)


_CURL = None


def _import_curl():
    global _CURL
    if _CURL is None:
        try:
            from curl_cffi import requests as cr
            _CURL = cr
        except ImportError:
            _die("curl_cffi not installed — run: ~/.config/x-cli/venv/bin/pip install curl_cffi")
    return _CURL


def _load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return None


def _save_json(path, obj):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
    os.chmod(path, 0o600)


def load_config():
    cfg = _load_json(CONFIG_PATH)
    if not cfg or not cfg.get("cookie"):
        _die("No config — run: x-cli set-cookie  (paste auth_token + ct0 from a logged-in browser)")
    return cfg


# ---- nested-json helpers ----

def _find_first(obj, key):
    st = [obj]
    while st:
        o = st.pop()
        if isinstance(o, dict):
            if key in o:
                return o[key]
            st.extend(o.values())
        elif isinstance(o, list):
            st.extend(o)
    return None


def _find_all(obj, key):
    st = [obj]
    while st:
        o = st.pop()
        if isinstance(o, dict):
            if key in o:
                yield o[key]
            st.extend(o.values())
        elif isinstance(o, list):
            st.extend(o)


def _deep(d, *keys):
    for k in keys:
        if not isinstance(d, dict):
            return None
        d = d.get(k)
    return d


# ---- http client ----

class XClient:
    def __init__(self, cfg):
        self.cookie = cfg["cookie"]
        self.ct0 = cfg["ct0"]
        self.bearer = cfg.get("bearer") or PUBLIC_BEARER
        self.ua = cfg.get("user_agent", DEFAULT_UA)
        self.min_interval = 0.8
        self._last = 0.0
        self._ids = None

    @classmethod
    def from_config(cls):
        return cls(load_config())

    def _headers(self):
        return {"authorization": "Bearer " + self.bearer, "cookie": self.cookie,
                "x-csrf-token": self.ct0, "x-twitter-active-user": "yes",
                "x-twitter-auth-type": "OAuth2Session", "x-twitter-client-language": "en",
                "content-type": "application/json", "accept": "*/*", "referer": "https://x.com/"}

    def _do(self, method, url, data=None, auth=True, retries=3):
        cr = _import_curl()
        gap = self.min_interval - (time.time() - self._last)
        if gap > 0:
            time.sleep(gap)
        headers = self._headers() if auth else {"cookie": self.cookie}
        for attempt in range(retries + 1):
            try:
                if method == "POST":
                    r = cr.post(url, impersonate="chrome", headers=headers, data=data, timeout=30)
                else:
                    r = cr.get(url, impersonate="chrome", headers=headers, timeout=30)
                self._last = time.time()
                return r
            except Exception as e:
                if attempt < retries:
                    time.sleep(2)
                    continue
                raise XError("network error: %s" % e)

    # -- queryId resolution (cached by JS build hash) --

    def resolve_queryids(self, force=False):
        if self._ids and not force:
            return self._ids
        html = self._do("GET", "https://x.com/home", auth=False).text
        mb = re.search(r"/client-web/main\.([0-9a-f]+)\.js", html)
        build = mb.group(1) if mb else "?"
        cache = _load_json(QUERYIDS_PATH) or {}
        if not force and cache.get("build") == build and cache.get("ids", {}).get("HomeTimeline"):
            self._ids = cache["ids"]
            return self._ids
        urls = sorted(set(re.findall(r"https://abs\.twimg\.com/responsive-web/client-web[^\"']+?\.js", html)))
        ids, main_text = {}, ""
        for u in urls:
            t = self._do("GET", u, auth=False).text
            if "/main." in u:
                main_text = t
            for qid, op in re.findall(r'queryId:"([^"]+)",operationName:"([^"]+)"', t):
                ids.setdefault(op, qid)
        if "HomeTimeline" not in ids:  # home ops live in an on-demand chunk
            blob = html + main_text
            chunks = [(cid, nm) for cid, nm in re.findall(r'(\d+):"([^"]+)"', blob)
                      if "HomeTimeline" in nm and "Adblock" not in nm]
            hashes = dict(re.findall(r'(\d+):"([0-9a-f]{6,16})"', blob))
            for cid, nm in chunks:
                if "HomeTimeline" in ids:
                    break
                h = hashes.get(cid)
                if not h:
                    continue
                try:
                    t = self._do("GET", "https://abs.twimg.com/responsive-web/client-web/%s.%sa.js"
                                 % (nm, h), auth=False).text
                    for qid, op in re.findall(r'queryId:"([^"]+)",operationName:"([^"]+)"', t):
                        ids.setdefault(op, qid)
                except Exception:
                    pass
        _save_json(QUERYIDS_PATH, {"build": build, "ids": ids})
        self._ids = ids
        return ids

    # -- graphql with feature auto-negotiation --

    def gql(self, op, variables, method="GET", field_toggles=None):
        qid = self.resolve_queryids().get(op)
        if not qid:
            raise XError("queryId for %s not found (X bundle layout changed)" % op)
        features = {}
        for _ in range(8):
            if method == "POST":
                body = {"variables": variables, "features": features, "queryId": qid}
                if field_toggles is not None:
                    body["fieldToggles"] = field_toggles
                r = self._do("POST", "%s/%s/%s" % (BASE_API, qid, op), data=json.dumps(body))
            else:
                params = {"variables": json.dumps(variables, separators=(",", ":")),
                          "features": json.dumps(features, separators=(",", ":"))}
                if field_toggles is not None:
                    params["fieldToggles"] = json.dumps(field_toggles, separators=(",", ":"))
                r = self._do("GET", "%s/%s/%s?%s" % (BASE_API, qid, op, urllib.parse.urlencode(params)))
            miss = _missing_features(r.text)
            if miss:
                for f in miss:
                    features[f] = True
                continue
            if r.status_code != 200:
                raise XError("HTTP %s from %s: %s" % (r.status_code, op, r.text[:200]))
            j = r.json()
            if j.get("errors") and not j.get("data"):
                raise XError("%s: %s" % (op, j["errors"][0].get("message", "graphql error")))
            return j
        raise XError("feature negotiation failed for %s" % op)


def _missing_features(text):
    m = re.search(r"following features cannot be null:\s*([a-z0-9_,\s]+)", text)
    return [x.strip() for x in m.group(1).split(",") if x.strip()] if m else []


# ---- parsing (X GraphQL -> stable dicts) ----

def _age(created_at):
    if not created_at:
        return "?"
    try:
        ts = parsedate_to_datetime(created_at).timestamp()
    except Exception:
        return "?"
    s = max(0.0, time.time() - ts)
    for unit, n in (("y", 31536000), ("mo", 2592000), ("d", 86400), ("h", 3600), ("m", 60)):
        if s >= n:
            return "%d%s" % (int(s // n), unit)
    return "%ds" % int(s)


def _num(n):
    if n is None:
        return "?"
    n = int(n)
    if n >= 1000000:
        return "%.1fM" % (n / 1e6)
    if n >= 1000:
        return "%.1fk" % (n / 1e3)
    return str(n)


def _media(legacy):
    ents = (legacy.get("extended_entities") or legacy.get("entities") or {}).get("media") or []
    out = []
    for m in ents:
        out.append({"type": m.get("type"), "url": m.get("media_url_https")})
    return out


def tweet_to_dict(res, text_max=None):
    if not res:
        return None
    if res.get("__typename") == "TweetWithVisibilityResults":
        res = res.get("tweet", res)
    if res.get("__typename") not in ("Tweet", None):
        return None
    legacy = res.get("legacy") or {}
    note = _deep(res, "note_tweet", "note_tweet_results", "result") or {}
    text = note.get("text") or legacy.get("full_text") or ""
    if text_max and len(text) > text_max:
        text = text[:text_max].rstrip() + "… (+%d chars)" % (len(text) - text_max)
    ures = _deep(res, "core", "user_results", "result") or {}
    ucore = ures.get("core") or {}
    author = ucore.get("screen_name")
    tid = res.get("rest_id") or legacy.get("id_str")
    views = _deep(res, "views", "count")
    quoted = _deep(res, "quoted_status_result", "result")
    qd = None
    if quoted:
        qres = quoted.get("tweet", quoted)
        qleg = qres.get("legacy") or {}
        qauth = _deep(qres, "core", "user_results", "result", "core", "screen_name")
        qd = {"author": qauth, "text": (qleg.get("full_text") or "")[:200]}
    return {
        "id": tid,
        "author": author,
        "author_name": ucore.get("name"),
        "verified": bool(ures.get("is_blue_verified")),
        "text": text,
        "created_at": legacy.get("created_at"),
        "age": _age(legacy.get("created_at")),
        "likes": legacy.get("favorite_count"),
        "retweets": legacy.get("retweet_count"),
        "replies": legacy.get("reply_count"),
        "quotes": legacy.get("quote_count"),
        "bookmarks": legacy.get("bookmark_count"),
        "views": int(views) if views else None,
        "lang": legacy.get("lang"),
        "url": "https://x.com/%s/status/%s" % (author or "i", tid),
        "is_retweet": "retweeted_status_result" in legacy,
        "is_quote": bool(legacy.get("is_quote_status")),
        "quoted": qd,
        "media": _media(legacy),
        "conversation_id": legacy.get("conversation_id_str"),
    }


def _entry_tweets(entry, text_max):
    content = entry.get("content") or {}
    typ = content.get("__typename")
    if typ == "TimelineTimelineItem":
        d = tweet_to_dict(_deep(content, "itemContent", "tweet_results", "result"), text_max)
        if d:
            yield d
    elif typ == "TimelineTimelineModule":
        for it in content.get("items") or []:
            d = tweet_to_dict(_deep(it, "item", "itemContent", "tweet_results", "result"), text_max)
            if d:
                yield d


def iter_timeline_tweets(resp, text_max=None):
    seen = set()
    for entries in _find_all(resp, "entries"):
        if not isinstance(entries, list):
            continue
        for e in entries:
            if not isinstance(e, dict):
                continue
            for d in _entry_tweets(e, text_max):
                if d["id"] and d["id"] not in seen:
                    seen.add(d["id"])
                    yield d


# ---- fetchers ----

def fetch_me(client):
    j = client.gql("Viewer", {"withCommunitiesMemberCount": False})
    sn = _find_first(j, "screen_name")
    if not sn:
        raise XError("not logged in — cookie/ct0 invalid or expired. Run: x-cli set-cookie")
    return {"screen_name": sn}


def fetch_user_id(client, handle):
    j = client.gql("UserByScreenName", {"screen_name": handle.lstrip("@")})
    uid = _find_first(j, "rest_id")
    if not uid:
        raise XError("user @%s not found" % handle.lstrip("@"))
    return uid


def fetch_user_tweets(client, handle, count=20, replies=False, text_max=None):
    uid = fetch_user_id(client, handle)
    op = "UserTweetsAndReplies" if replies else "UserTweets"
    j = client.gql(op, {"userId": uid, "count": count, "includePromotedContent": False,
                        "withQuickPromoteEligibilityTweetFields": False, "withVoice": False,
                        "withV2Timeline": True})
    return list(iter_timeline_tweets(j, text_max))[:count]


def fetch_home(client, count=20, latest=False, text_max=None):
    op = "HomeLatestTimeline" if latest else "HomeTimeline"
    j = client.gql(op, {"count": count, "includePromotedContent": False,
                        "latestControlAvailable": True, "withCommunity": True, "seenTweetIds": []},
                   method="POST")
    return list(iter_timeline_tweets(j, text_max))[:count]


# Plain SearchTimeline is gated behind x-client-transaction-id (404 without it); these
# post-search ops return the same general results and are not gated.
SEARCH_OPS = {"Latest": "GlobalCommunitiesLatestPostSearchTimeline",
              "Top": "GlobalCommunitiesPostSearchTimeline"}


def fetch_search(client, query, count=20, product="Latest", text_max=None):
    op = SEARCH_OPS.get(product, SEARCH_OPS["Latest"])
    j = client.gql(op, {"rawQuery": query, "count": count,
                        "querySource": "typed_query", "product": product})
    return list(iter_timeline_tweets(j, text_max))[:count]


def _parse_tweet_id(ref):
    ref = ref.strip()
    m = re.search(r"/status/(\d+)", ref)
    if m:
        return m.group(1)
    if ref.isdigit():
        return ref
    raise XError("could not parse a tweet id from %r" % ref)


def fetch_tweet(client, ref, replies_limit=40, text_max=None):
    tid = _parse_tweet_id(ref)
    ft = {"withArticleRichContentState": True, "withArticlePlainText": False,
          "withGrokAnalyze": False, "withDisallowedReplyControls": False}
    j = client.gql("TweetDetail", {"focalTweetId": tid, "with_rux_injections": False,
                                   "rankingMode": "Relevance", "includePromotedContent": False,
                                   "withCommunity": True, "withQuickPromoteEligibilityTweetFields": True,
                                   "withBirdwatchNotes": True, "withVoice": True},
                   field_toggles=ft)
    tweets = list(iter_timeline_tweets(j, text_max))
    focal = next((t for t in tweets if t["id"] == tid), tweets[0] if tweets else None)
    replies = [t for t in tweets if t["id"] != tid][:replies_limit]
    return {"tweet": focal, "replies": replies}


# ---- renderers ----

def _metrics(t):
    return "♥%s ↻%s ↩%s%s" % (_num(t["likes"]), _num(t["retweets"]), _num(t["replies"]),
                             (" 👁%s" % _num(t["views"])) if t.get("views") else "")


def _tweet_line(t, n=None):
    v = " ✓" if t.get("verified") else ""
    head = "@%s (%s)%s · %s · %s · id=%s" % (t["author"] or "?", t.get("author_name") or "",
                                             v, t["age"], _metrics(t), t["id"])
    return ("%d. %s" % (n, head)) if n else head


def _tweet_body(t, indent="   "):
    lines = []
    for bl in (t["text"] or "").splitlines() or [""]:
        lines.append(indent + bl)
    if t.get("quoted"):
        lines.append("%s⤷ quote @%s: %s" % (indent, t["quoted"].get("author"), t["quoted"].get("text", "")))
    if t.get("media"):
        kinds = ", ".join("%s" % m["type"] for m in t["media"])
        lines.append("%smedia: %s" % (indent, kinds))
    return lines


def render_tweets_text(tweets, header):
    lines = [header]
    for i, t in enumerate(tweets, 1):
        lines.append(_tweet_line(t, i))
        lines.extend(_tweet_body(t))
    return "\n".join(lines)


def render_thread_text(data):
    t = data["tweet"]
    if not t:
        return "(tweet not found)"
    lines = [_tweet_line(t), "# " + (t["text"] or "").split("\n")[0][:100]]
    lines.extend(_tweet_body(t, indent=""))
    lines.append("")
    lines.append("--- replies (%d) ---" % len(data["replies"]))
    for r in data["replies"]:
        lines.append(_tweet_line(r))
        lines.extend(_tweet_body(r))
    return "\n".join(lines)


def _emit(args, data, text):
    print(json.dumps(data, ensure_ascii=False, indent=2) if args.json else text)


# ---- cookie setup ----

def _cookie_from_input(text):
    text = "\n".join(l for l in text.splitlines() if not l.strip().startswith("#"))
    for pat in (r"-H\s+['\"]cookie:\s*([^'\"]+)['\"]", r"-b\s+['\"]([^'\"]+)['\"]",
                r"(?:^|\n)\s*cookie:\s*(.+)"):
        m = re.search(pat, text, re.I)
        if m:
            text = m.group(1)
            break
    pairs = re.findall(r"(\w+)=([^;\s]+)", text)
    return "; ".join("%s=%s" % (k, v) for k, v in pairs)


def cmd_set_cookie(args):
    raw = sys.stdin.read() if not sys.stdin.isatty() else input("Paste cookie (auth_token=…; ct0=…) or Copy-as-cURL:\n")
    cookie = _cookie_from_input(raw)
    names = dict(p.split("=", 1) for p in cookie.split("; ") if "=" in p)
    if "auth_token" not in names or "ct0" not in names:
        _die("cookie must contain auth_token and ct0 (got: %s)" % ", ".join(names) or "none")
    ua = re.search(r"-H\s+['\"]user-agent:\s*([^'\"]+)['\"]", raw, re.I)
    mb = re.search(r"-H\s+['\"]authorization:\s*Bearer\s+([^'\"]+)['\"]", raw, re.I)
    cfg = {"cookie": cookie, "ct0": names["ct0"], "bearer": mb.group(1) if mb else PUBLIC_BEARER,
           "user_agent": ua.group(1) if ua else DEFAULT_UA}
    if not args.no_verify:
        me = fetch_me(XClient(cfg))
        print("OK, logged in as @%s" % me["screen_name"])
    _save_json(CONFIG_PATH, cfg)
    print("Saved to %s (chmod 600)." % CONFIG_PATH)


# ---- commands ----

def cmd_me(args):
    me = fetch_me(XClient.from_config())
    _emit(args, me, "@%s" % me["screen_name"])


def cmd_home(args):
    tw = fetch_home(XClient.from_config(), count=args.limit, latest=args.latest,
                    text_max=(None if args.full else args.text_max))
    _emit(args, tw, render_tweets_text(tw, "# home %s · %d tweets"
                                       % ("latest" if args.latest else "for-you", len(tw))))


def cmd_user(args):
    tw = fetch_user_tweets(XClient.from_config(), args.handle, count=args.limit,
                           replies=args.replies, text_max=(None if args.full else args.text_max))
    _emit(args, tw, render_tweets_text(tw, "# @%s %s · %d tweets"
                                       % (args.handle.lstrip("@"), "+replies" if args.replies else "", len(tw))))


def cmd_search(args):
    tw = fetch_search(XClient.from_config(), args.query, count=args.limit, product=args.product,
                      text_max=(None if args.full else args.text_max))
    _emit(args, tw, render_tweets_text(tw, "# search %r (%s) · %d tweets" % (args.query, args.product, len(tw))))


def cmd_tweet(args):
    data = fetch_tweet(XClient.from_config(), args.ref, replies_limit=args.replies,
                       text_max=(None if args.full else args.text_max))
    _emit(args, data, render_thread_text(data))


def build_parser():
    p = argparse.ArgumentParser(prog="x-cli", description="Read X/Twitter via a logged-in cookie.")
    p.add_argument("--json", action="store_true", help="emit JSON instead of text")
    sub = p.add_subparsers(dest="cmd", required=True)

    sc = sub.add_parser("set-cookie", help="store auth_token+ct0 (or Copy-as-cURL) from stdin")
    sc.add_argument("--no-verify", action="store_true")

    sub.add_parser("me", help="auth check (whoami)")

    hp = sub.add_parser("home", help="your home timeline")
    hp.add_argument("--latest", action="store_true", help="Following (chrono) instead of For You")
    hp.add_argument("--limit", type=int, default=20)

    up = sub.add_parser("user", help="a user's tweets")
    up.add_argument("handle", help="@handle (or handle)")
    up.add_argument("--replies", action="store_true", help="include replies")
    up.add_argument("--limit", type=int, default=20)

    spr = sub.add_parser("search", help="search tweets")
    spr.add_argument("query")
    spr.add_argument("--product", default="Latest", choices=["Latest", "Top"])
    spr.add_argument("--limit", type=int, default=20)

    tp = sub.add_parser("tweet", help="a tweet + its replies")
    tp.add_argument("ref", help="url or tweet id")
    tp.add_argument("--replies", type=int, default=40, help="max replies")

    for q in (hp, up, spr, tp):
        q.add_argument("--text-max", type=int, default=280, help="truncate each tweet body")
        q.add_argument("--full", action="store_true", help="full tweet text, no truncation")
    return p


def main():
    args = build_parser().parse_args()
    {"set-cookie": cmd_set_cookie, "me": cmd_me, "home": cmd_home, "user": cmd_user,
     "search": cmd_search, "tweet": cmd_tweet}[args.cmd](args)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except KeyboardInterrupt:
        raise SystemExit(130)
    except XError as e:
        _die("error: %s" % e)
    except Exception as e:
        _die("error: %s: %s" % (type(e).__name__, e))
