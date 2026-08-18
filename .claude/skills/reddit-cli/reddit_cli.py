#!/usr/bin/env python3
"""Read Reddit from the CLI as a logged-in user, browserless, no app registration.

Auth = the full session cookie from a logged-in browser (reddit_session + token_v2 + …).
Transport = curl_cffi with Chrome TLS impersonation — required, because Reddit blocks
non-browser TLS fingerprints. With both, www.reddit.com's `.json` endpoints return the
real personalized JSON (home feed, subreddits, posts+comments).

Output is optimized for an LLM reader: compact text by default, `--json` for a stable
schema (the contract for a future digest layer). Importable: build a RedditClient, then
fetch_post / fetch_feed / fetch_subreddit / fetch_me.
"""

import argparse
import json
import os
import re
import sys
import time
import urllib.parse
from pathlib import Path

CONFIG_DIR = Path(os.path.expanduser("~/.config/reddit-cli"))
CONFIG_PATH = CONFIG_DIR / "config.json"
BASE = "https://www.reddit.com"
DEFAULT_UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36")

FRONT_SORTS = {"best", "hot", "new", "top", "rising", "controversial"}
SUB_SORTS = {"hot", "new", "top", "rising", "controversial"}
TIME_SORTS = {"top", "controversial"}
POST_SORTS = ["top", "confidence", "new", "controversial", "old", "qa"]
TIME_CHOICES = ["hour", "day", "week", "month", "year", "all"]


class RedditError(RuntimeError):
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
            _die("curl_cffi not installed — run: "
                 "~/.config/reddit-cli/venv/bin/pip install curl_cffi")
    return _CURL


# ---- config ----

def load_config():
    if not CONFIG_PATH.exists():
        _die("No config — run: reddit-cli set-cookie  (paste a logged-in browser cookie)")
    with open(CONFIG_PATH) as f:
        return json.load(f)


def load_config_or_empty():
    return json.load(open(CONFIG_PATH)) if CONFIG_PATH.exists() else {}


def save_config(cfg):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)
    os.chmod(CONFIG_PATH, 0o600)


# ---- http client ----

class RedditClient:
    def __init__(self, cookie, user_agent=DEFAULT_UA, impersonate="chrome", min_interval=0.7):
        self.cookie = cookie
        self.ua = user_agent
        self.impersonate = impersonate
        self.min_interval = min_interval
        self._last = 0.0

    @classmethod
    def from_config(cls, cfg=None):
        cfg = cfg or load_config()
        if not cfg.get("cookie"):
            _die("cookie is empty in config — run: reddit-cli set-cookie")
        return cls(cfg["cookie"], cfg.get("user_agent", DEFAULT_UA), cfg.get("impersonate", "chrome"))

    def get_json(self, path, params=None):
        params = dict(params or {})
        params.setdefault("raw_json", 1)
        url = "%s%s?%s" % (BASE, path, urllib.parse.urlencode(params))
        return self._request(url)

    def _request(self, url, retries=3):
        cr = _import_curl()
        gap = self.min_interval - (time.time() - self._last)
        if gap > 0:
            time.sleep(gap)
        for attempt in range(retries + 1):
            try:
                r = cr.get(url, impersonate=self.impersonate,
                           headers={"Cookie": self.cookie}, timeout=30)
            except Exception as e:
                if attempt < retries:
                    time.sleep(2)
                    continue
                raise RedditError("network error: %s" % e)
            self._last = time.time()
            sc = r.status_code
            if sc == 200:
                ct = r.headers.get("content-type", "")
                if "json" not in ct:
                    raise RedditError("expected JSON, got %s (len=%d) — cookie likely de-authed "
                                      "or blocked; refresh it with set-cookie" % (ct[:40], len(r.text)))
                obj = r.json()
                if isinstance(obj, dict) and obj.get("error") and "data" not in obj:
                    raise RedditError("Reddit error %s: %s" % (obj.get("error"), obj.get("message", "")))
                return obj
            if sc == 429 and attempt < retries:
                time.sleep(min(int(r.headers.get("retry-after") or 3), 15))
                continue
            raise RedditError(_http_err(sc))


def _http_err(sc):
    if sc in (401, 403):
        return ("Reddit returned %d — cookie de-authorized/expired, or target is "
                "private/quarantined. Refresh: reddit-cli set-cookie" % sc)
    if sc == 404:
        return "Reddit returned 404 — not found (bad id or subreddit name)."
    return "Reddit returned HTTP %d" % sc


# ---- helpers ----

def _age(created_utc):
    if not created_utc:
        return "?"
    s = max(0.0, time.time() - created_utc)
    for unit, n in (("y", 31536000), ("mo", 2592000), ("d", 86400),
                    ("h", 3600), ("m", 60)):
        if s >= n:
            return "%d%s" % (int(s // n), unit)
    return "%ds" % int(s)


def _trunc(text, n):
    text = (text or "").strip()
    if n is None or len(text) <= n:
        return text
    return text[:n].rstrip() + "… (+%d chars)" % (len(text) - n)


def _strip_prefix(value, kind):
    return re.sub(r"^/?%s/" % kind, "", value.strip(), flags=re.I)


def parse_submission_id(ref):
    ref = ref.strip()
    if ref.startswith("t3_"):
        return ref[3:]
    m = re.search(r"/comments/([a-z0-9]{4,10})", ref, re.I)
    if m:
        return m.group(1)
    m = re.search(r"redd\.it/([a-z0-9]{4,10})", ref, re.I)
    if m:
        return m.group(1)
    if re.fullmatch(r"[a-z0-9]{4,10}", ref, re.I):
        return ref
    return None


# ---- normalization (raw .json -> stable dicts) ----

def post_to_dict(d, body_max=None):
    author = d.get("author")
    if author == "[deleted]":
        author = None
    is_self = bool(d.get("is_self"))
    return {
        "id": d.get("id"),
        "fullname": d.get("name"),
        "title": d.get("title"),
        "author": author,
        "subreddit": d.get("subreddit"),
        "score": d.get("score"),
        "upvote_ratio": d.get("upvote_ratio"),
        "num_comments": d.get("num_comments"),
        "created_utc": d.get("created_utc"),
        "age": _age(d.get("created_utc")),
        "permalink": "https://reddit.com" + (d.get("permalink") or ""),
        "url": d.get("url"),
        "is_self": is_self,
        "selftext": _trunc(d.get("selftext") or "", body_max) if is_self else "",
        "selftext_len": len(d.get("selftext") or ""),
        "domain": d.get("domain"),
        "flair": d.get("link_flair_text"),
        "over_18": bool(d.get("over_18")),
        "spoiler": bool(d.get("spoiler")),
        "stickied": bool(d.get("stickied")),
    }


def comment_to_dict(d, depth, body_max=None):
    author = d.get("author")
    if author == "[deleted]":
        author = None
    return {
        "id": d.get("id"),
        "author": author,
        "score": d.get("score", d.get("ups")),
        "body": _trunc(d.get("body") or "", body_max),
        "created_utc": d.get("created_utc"),
        "age": _age(d.get("created_utc")),
        "depth": depth,
        "is_submitter": bool(d.get("is_submitter")),
        "distinguished": d.get("distinguished"),
        "stickied": bool(d.get("stickied")),
    }


def _walk(children, max_depth, remaining, body_max, depth=0):
    # score-sorted DFS, globally capped via the single-element `remaining` box;
    # `kind == "more"` stubs (load-more placeholders) are skipped.
    nodes = [c["data"] for c in children if c.get("kind") == "t1"]
    nodes.sort(key=lambda d: d.get("score") or 0, reverse=True)
    out = []
    for d in nodes:
        if remaining[0] <= 0:
            break
        node = comment_to_dict(d, depth, body_max=body_max)
        remaining[0] -= 1
        replies = d.get("replies")
        kids = replies["data"]["children"] if isinstance(replies, dict) else []
        if depth + 1 < max_depth and remaining[0] > 0:
            node["replies"] = _walk(kids, max_depth, remaining, body_max, depth + 1)
        else:
            node["replies"] = []
        out.append(node)
    return out


# ---- fetchers (importable API) ----

def _check_sort(sort, allowed, what):
    if sort not in allowed:
        raise RedditError("invalid %s sort %r (choose from %s)" % (what, sort, sorted(allowed)))
    return sort


def _listing_posts(resp, body_max):
    return [post_to_dict(c["data"], body_max)
            for c in resp["data"]["children"] if c.get("kind") == "t3"]


def fetch_post(client, ref, sort="top", max_depth=4, max_comments=40,
               body_max=None, comment_max=None):
    sub_id = parse_submission_id(ref)
    if not sub_id:
        raise RedditError("could not parse a post id from %r" % ref)
    resp = client.get_json("/comments/%s.json" % sub_id, {
        "limit": max(max_comments * 2, 50), "depth": max_depth,
        "sort": sort, "context": 0})
    listing = resp[0]["data"]["children"]
    if not listing:
        raise RedditError("post %s not found" % sub_id)
    data = post_to_dict(listing[0]["data"], body_max=body_max)
    remaining = [max_comments]
    data["comments"] = _walk(resp[1]["data"]["children"], max_depth, remaining, comment_max)
    data["comments_shown"] = max_comments - remaining[0]
    return data


def fetch_feed(client, sort="best", limit=25, time_filter="day", body_max=500):
    sort = _check_sort(sort, FRONT_SORTS, "feed")
    params = {"limit": limit}
    if sort in TIME_SORTS:
        params["t"] = time_filter
    return _listing_posts(client.get_json("/%s.json" % sort, params), body_max)


def fetch_subreddit(client, name, sort="hot", limit=25, time_filter="day", body_max=500):
    sort = _check_sort(sort, SUB_SORTS, "subreddit")
    params = {"limit": limit}
    if sort in TIME_SORTS:
        params["t"] = time_filter
    path = "/r/%s/%s.json" % (_strip_prefix(name, "r"), sort)
    return _listing_posts(client.get_json(path, params), body_max)


def fetch_me(client):
    resp = client.get_json("/api/me.json")
    data = resp.get("data") if isinstance(resp, dict) else None
    if not data or not data.get("name"):
        raise RedditError("not logged in — cookie missing/expired. Run: reddit-cli set-cookie")
    return {"name": data["name"], "link_karma": data.get("link_karma"),
            "comment_karma": data.get("comment_karma"), "created_utc": data.get("created_utc")}


# ---- text renderers ----

def _ratio(p):
    r = p.get("upvote_ratio")
    return ("%d%%" % round(r * 100)) if r is not None else "?"


def _tags(p):
    t = [k for k, on in (("NSFW", p.get("over_18")), ("spoiler", p.get("spoiler")),
                         ("pinned", p.get("stickied"))) if on]
    return (" [" + ",".join(t) + "]") if t else ""


def render_listing_text(posts, header):
    lines = [header]
    for i, p in enumerate(posts, 1):
        kind = "self" if p["is_self"] else (p.get("domain") or "link")
        flair = (" {%s}" % p["flair"]) if p.get("flair") else ""
        lines.append("%d. [+%s·%s] %s (%s) — r/%s · u/%s · %sc · %s · id=%s%s%s" % (
            i, p["score"], _ratio(p), p["title"], kind, p["subreddit"],
            p["author"] or "[deleted]", p["num_comments"], p["age"], p["id"],
            flair, _tags(p)))
        if not p["is_self"] and p.get("url"):
            lines.append("   link: %s" % p["url"])
        body = (p.get("selftext") or "").strip()
        if body:
            lines.extend("   > " + bl for bl in body.splitlines())
    return "\n".join(lines)


def render_post_text(p):
    lines = ["r/%s · [+%s·%s] · u/%s · %s · %s comments · id=%s%s" % (
        p["subreddit"], p["score"], _ratio(p), p["author"] or "[deleted]",
        p["age"], p["num_comments"], p["id"], _tags(p))]
    lines.append("# " + (p["title"] or ""))
    if p.get("flair"):
        lines.append("flair: " + p["flair"])
    if not p["is_self"]:
        lines.append("link: " + (p.get("url") or ""))
    if p.get("selftext"):
        lines.extend(["", p["selftext"]])
    lines.extend(["", "--- comments (%d shown of %d) ---" % (
        p.get("comments_shown", 0), p["num_comments"])])

    def walk(nodes):
        for c in nodes:
            indent = "  " * c["depth"]
            who = "u/%s" % (c["author"] or "[deleted]")
            if c.get("is_submitter"):
                who += "(OP)"
            if c.get("distinguished") == "moderator":
                who += "[MOD]"
            blines = (c["body"] or "").strip().splitlines() or [""]
            lines.append("%s[+%s] %s: %s" % (indent, c["score"], who, blines[0]))
            lines.extend("%s  %s" % (indent, x) for x in blines[1:])
            walk(c.get("replies", []))

    walk(p.get("comments", []))
    return "\n".join(lines)


def _emit(args, data, text):
    print(json.dumps(data, ensure_ascii=False, indent=2) if args.json else text)


# ---- cookie acquisition ----

def cookie_from_input(text):
    text = text.strip()
    for pat in (r"-H\s+['\"]cookie:\s*([^'\"]+)['\"]",
                r"-b\s+['\"]([^'\"]+)['\"]",
                r"(?:^|\n)\s*cookie:\s*(.+)"):
        m = re.search(pat, text, re.I)
        if m:
            return m.group(1).strip()
    return text


def ua_from_curl(text):
    m = re.search(r"-H\s+['\"]user-agent:\s*([^'\"]+)['\"]", text, re.I)
    return m.group(1).strip() if m else None


def _verify_and_save(cfg, no_verify=False):
    if not no_verify:
        me = fetch_me(RedditClient.from_config(cfg))
        print("OK, logged in as u/%s" % me["name"])
    save_config(cfg)
    print("Saved to %s (chmod 600)." % CONFIG_PATH)


# ---- commands ----

def cmd_set_cookie(args):
    # Reads stdin: a raw Cookie header, OR a full "Copy as cURL" blob (best — carries
    # the full cookie + the matching User-Agent). Lines starting with # are ignored.
    if sys.stdin.isatty():
        raw = input("Paste the Cookie header (one line), then Enter:\n")
    else:
        raw = sys.stdin.read()
    raw = "\n".join(l for l in raw.splitlines() if not l.strip().startswith("#"))
    cookie = cookie_from_input(raw)
    if not cookie:
        _die("empty cookie")
    if "reddit_session" not in cookie:
        print("warn: no 'reddit_session' in the cookie — feed will be anonymous/blocked. "
              "Copy the main www.reddit.com document request (Network → Doc).", file=sys.stderr)
    cfg = load_config_or_empty()
    cfg.pop("_comment", None)
    cfg["cookie"] = cookie
    ua = ua_from_curl(raw)
    cfg["user_agent"] = ua or cfg.get("user_agent") or DEFAULT_UA
    _verify_and_save(cfg, no_verify=args.no_verify)


def cmd_me(args):
    me = fetch_me(RedditClient.from_config())
    _emit(args, me, "u/%s · link karma %s · comment karma %s"
          % (me["name"], me["link_karma"], me["comment_karma"]))


def cmd_post(args):
    data = fetch_post(RedditClient.from_config(), args.ref, sort=args.sort,
                      max_depth=args.depth, max_comments=args.comments,
                      body_max=args.body_max, comment_max=args.comment_max)
    _emit(args, data, render_post_text(data))


def cmd_feed(args):
    posts = fetch_feed(RedditClient.from_config(), sort=args.sort, limit=args.limit,
                       time_filter=args.time, body_max=(None if args.full else args.body_max))
    _emit(args, posts, render_listing_text(
        posts, "# home feed · sort=%s · %d posts" % (args.sort, len(posts))))


def cmd_sub(args):
    posts = fetch_subreddit(RedditClient.from_config(), args.name, sort=args.sort,
                            limit=args.limit, time_filter=args.time,
                            body_max=(None if args.full else args.body_max))
    _emit(args, posts, render_listing_text(
        posts, "# r/%s · sort=%s · %d posts" % (_strip_prefix(args.name, "r"), args.sort, len(posts))))


def build_parser():
    p = argparse.ArgumentParser(prog="reddit-cli", description="Read Reddit via a logged-in cookie.")
    p.add_argument("--json", action="store_true", help="emit JSON instead of text")
    sub = p.add_subparsers(dest="cmd", required=True)

    sc = sub.add_parser("set-cookie", help="store a cookie / Copy-as-cURL from a logged-in browser (stdin)")
    sc.add_argument("--no-verify", action="store_true")

    sub.add_parser("me", help="auth check (whoami + karma)")

    pp = sub.add_parser("post", help="a post with its comment tree")
    pp.add_argument("ref", help="url, /comments/<id>, t3_<id>, redd.it/<id>, or bare id")
    pp.add_argument("--sort", default="top", choices=POST_SORTS)
    pp.add_argument("--depth", type=int, default=4)
    pp.add_argument("--comments", type=int, default=40, help="max comments total (by score)")
    pp.add_argument("--comment-max", type=int, default=None, help="truncate each comment body")
    pp.add_argument("--body-max", type=int, default=None, help="truncate selftext")

    fp = sub.add_parser("feed", help="your home feed (subscribed)")
    fp.add_argument("--sort", default="best", choices=sorted(FRONT_SORTS))
    fp.add_argument("--time", default="day", choices=TIME_CHOICES, help="window for top/controversial")
    fp.add_argument("--limit", type=int, default=25)
    fp.add_argument("--body-max", type=int, default=500)
    fp.add_argument("--full", action="store_true", help="full selftext, no truncation")

    sp = sub.add_parser("sub", help="a subreddit")
    sp.add_argument("name", help="subreddit (r/ prefix optional)")
    sp.add_argument("--sort", default="hot", choices=sorted(SUB_SORTS))
    sp.add_argument("--time", default="day", choices=TIME_CHOICES, help="window for top/controversial")
    sp.add_argument("--limit", type=int, default=25)
    sp.add_argument("--body-max", type=int, default=500)
    sp.add_argument("--full", action="store_true", help="full selftext, no truncation")
    return p


def main():
    args = build_parser().parse_args()
    {"set-cookie": cmd_set_cookie, "me": cmd_me, "post": cmd_post,
     "feed": cmd_feed, "sub": cmd_sub}[args.cmd](args)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except KeyboardInterrupt:
        raise SystemExit(130)
    except RedditError as e:
        _die("error: %s" % e)
    except Exception as e:
        _die("error: %s: %s" % (type(e).__name__, e))
