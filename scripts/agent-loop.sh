#!/usr/bin/env bash
# Closed agent loop: same prompt, fresh context each pass, eval gate decides when to stop.
set -euo pipefail

PROMPT_FILE="LOOP.md"
GATE=""
MAX=10
MODEL=""
PROMISE="LOOP_DONE"
WORKDIR="$PWD"
MINUTES=0

usage() {
  cat <<'EOF'
agent-loop.sh — run a coding agent in a closed loop until an eval gate goes green.

  agent-loop.sh [options]
  agent-loop.sh --init            write a LOOP.md skeleton and exit

Options:
  -p, --prompt FILE   goal file, unchanged across iterations (default: LOOP.md)
  -g, --gate CMD      eval gate; exit 0 means done. Without it the loop is "open"
                      and only --max / --promise can stop it.
  -n, --max N         iteration cap (default: 10)
  -t, --minutes N     wall-clock cap (default: none)
  -m, --model NAME    model passed to claude
      --promise STR   completion string the agent must print (default: LOOP_DONE)
  -C, --dir PATH      working directory (default: cwd)

Example:
  agent-loop.sh -g 'npm test' -n 20
EOF
}

init_prompt() {
  cat <<'EOF'
# Goal

<one sentence, testable>

# Done when

- [ ] the eval gate exits 0
- [ ] <other checkable conditions>

# Constraints

- <what you must not touch>

# Out of scope

- <what to explicitly skip>
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --init) init_prompt > "${2:-LOOP.md}"; echo "wrote ${2:-LOOP.md}"; exit 0 ;;
    -p|--prompt) PROMPT_FILE="$2"; shift 2 ;;
    -g|--gate) GATE="$2"; shift 2 ;;
    -n|--max) MAX="$2"; shift 2 ;;
    -t|--minutes) MINUTES="$2"; shift 2 ;;
    -m|--model) MODEL="$2"; shift 2 ;;
    --promise) PROMISE="$2"; shift 2 ;;
    -C|--dir) WORKDIR="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

cd "$WORKDIR"
[ -f "$PROMPT_FILE" ] || { echo "no prompt file: $PROMPT_FILE (run --init)" >&2; exit 1; }

STATE_DIR=".agent-loop"
RUN_DIR="$STATE_DIR/$(date +%Y%m%d-%H%M%S)"
PROGRESS="$STATE_DIR/PROGRESS.md"
mkdir -p "$RUN_DIR"
[ -f "$PROGRESS" ] || printf '# Progress ledger\n\nAppend one short entry per iteration: what changed, what the gate said, what is next.\n' > "$PROGRESS"

STARTED=$(date +%s)
GATE_LOG=""

run_gate() {
  [ -n "$GATE" ] || return 1
  GATE_LOG="$1"
  eval "$GATE" > "$GATE_LOG" 2>&1
}

finish() {
  echo
  echo "== $1 after $2 iteration(s); logs in $RUN_DIR"
  exit "$3"
}

if run_gate "$RUN_DIR/gate-00.log"; then
  finish "gate already green" 0 0
fi

i=0
while [ "$i" -lt "$MAX" ]; do
  i=$((i + 1))
  if [ "$MINUTES" -gt 0 ] && [ $(( ($(date +%s) - STARTED) / 60 )) -ge "$MINUTES" ]; then
    finish "time budget spent" "$((i - 1))" 1
  fi

  n=$(printf '%02d' "$i")
  OUT="$RUN_DIR/iter-$n.md"
  echo "== iteration $i/$MAX"

  {
    cat "$PROMPT_FILE"
    echo
    echo "## Loop protocol"
    echo
    echo "Iteration $i of $MAX. You start with a fresh context every time."
    echo "\`$PROGRESS\` is your only memory: read it first, append one short entry before you finish."
    echo "Do the smallest next step that moves the gate toward green. Do not restate the plan or re-explain the goal."
    if [ -n "$GATE" ]; then
      echo "Eval gate: \`$GATE\` — it must exit 0. It runs after you stop, so leave the tree in a state where it can."
    fi
    echo "Print <promise>$PROMISE</promise> only when the goal is completely and unequivocally true. Never to escape the loop."
    if [ -n "$GATE_LOG" ] && [ -s "$GATE_LOG" ]; then
      echo
      echo "## Last gate failure (tail)"
      echo '```'
      tail -n 60 "$GATE_LOG"
      echo '```'
    fi
  } | claude -p --dangerously-skip-permissions ${MODEL:+--model "$MODEL"} > "$OUT" 2>&1 || true

  tail -n 5 "$OUT"

  if run_gate "$RUN_DIR/gate-$n.log"; then
    finish "gate green" "$i" 0
  fi

  if [ -z "$GATE" ] && grep -qF "<promise>$PROMISE</promise>" "$OUT"; then
    finish "promise kept" "$i" 0
  fi
done

finish "iteration cap reached, gate still red" "$MAX" 1
