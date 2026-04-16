#!/bin/zsh

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

output=""

os_icon=""
if [[ "$OSTYPE" == "darwin"* ]]; then
  os_icon=" "
fi

if [[ -n "$os_icon" ]]; then
  output="${output}${os_icon} "
fi

dir_path="${cwd/#$HOME/~}"
output="${output}${dir_path} "

if [[ -d "$cwd/.git" ]] || git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks branch --show-current 2>/dev/null)
  if [[ -n "$branch" ]]; then
    git_status=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    
    if [[ -n "$git_status" ]]; then
      output="${output} ${branch}"
    else
      output="${output} ${branch}"
    fi
  fi
fi

printf "%s" "$output"
