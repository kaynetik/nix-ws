#!/usr/bin/env bash
# Prevent committing secrets.nix
if git diff --cached --name-only --diff-filter=A | grep -q "^nixos/secrets\.nix$"; then
  echo "ERROR: secrets.nix should not be committed! It contains sensitive data and is gitignored."
  exit 1
fi
exit 0
