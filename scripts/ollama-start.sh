#!/bin/bash
CONF="$HOME/dotfiles/ollama.conf"
source "$CONF"
/usr/local/bin/ollama run "$OLLAMA_MODEL" --keepalive 0 < /dev/null > /dev/null 2>&1
