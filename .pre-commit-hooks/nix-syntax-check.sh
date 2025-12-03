#!/usr/bin/env bash
# Check Nix syntax for all passed files
for file in "$@"; do
  if ! nix-instantiate --parse "$file" >/dev/null 2>&1; then
    echo "Syntax error in $file"
    exit 1
  fi
done
