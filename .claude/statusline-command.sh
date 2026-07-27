#!/bin/zsh
# Claude Code status line: dir · branch · context% · 5h window% · model · effort

input=$(cat)

IFS=$'\t' read -r cwd effort ctx five_hour five_reset model <<< "$(
  print -r -- "$input" | jq -r '
    [ (.workspace.current_dir // "."),
      (.effort.level // "?"),
      (.context_window.used_percentage // -1 | floor),
      (.rate_limits.five_hour.used_percentage // -1 | floor),
      (.rate_limits.five_hour.resets_at // 0),
      (.model.display_name // .model.id // "?")
    ] | @tsv'
)"

dim=$'\e[2m'; rst=$'\e[0m'
grn=$'\e[32m'; yel=$'\e[33m'; red=$'\e[31m'; cyn=$'\e[36m'; mag=$'\e[35m'; blu=$'\e[34m'

# color by fill level
heat() {
  if   (( $1 < 0 ));  then print -n -- "$dim"
  elif (( $1 < 60 )); then print -n -- "$grn"
  elif (( $1 < 85 )); then print -n -- "$yel"
  else                     print -n -- "$red"
  fi
}

# percent, or em dash when value is unavailable
pct() { (( $1 < 0 )) && print -n -- "${dim}—${rst}" || print -n -- "$(heat $1)$1%$rst"; }

sep=" ${dim}·${rst} "
out=""

[[ "$OSTYPE" == darwin* ]] && out=" "

out+="${cwd/#$HOME/~}"

if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  [[ -n "$branch" ]] && out+=" ${blu} ${branch}${rst}"
fi

out+="${sep}${cyn}ctx${rst} $(pct $ctx)"
out+="${sep}${cyn}5h${rst} $(pct $five_hour)"

# time remaining in the 5h window
if (( five_reset > 0 )); then
  left=$(( five_reset - $(date +%s) ))
  (( left > 0 )) && out+=" ${dim}($(( left / 3600 ))h$(printf '%02d' $(( (left % 3600) / 60 )))m)${rst}"
fi

out+="${sep}${dim}${model}${rst}"
out+="${sep}${mag}⚡ ${effort}${rst}"

printf '%s' "$out"
