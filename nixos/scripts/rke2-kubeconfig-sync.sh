#!/usr/bin/env bash
set -euo pipefail

source="/etc/rancher/rke2/rke2.yaml"
target="/home/kayws/.kube/config"
user="kayws"

uid=$(id -u "$user" 2>/dev/null || echo "")
gid=$(id -g "$user" 2>/dev/null || echo "")

if [ -z "$uid" ] || [ -z "$gid" ]; then
  echo "User $user not found, skipping"
  exit 0
fi

# Wait for source to exist
for i in {1..60}; do
  [ -f "$source" ] && break
  [ $i -eq 60 ] && { echo "Source kubeconfig not found"; exit 0; }
  sleep 1
done

# Create .kube dir if needed
mkdir -p "$(dirname "$target")"
chown "$uid:$gid" "$(dirname "$target")"
chmod 700 "$(dirname "$target")"

# Only update if source is newer or different
if [ ! -f "$target" ] || [ "$source" -nt "$target" ] || ! cmp -s "$source" "$target" 2>/dev/null; then
  # Backup if exists and different
  if [ -f "$target" ] && ! cmp -s "$source" "$target" 2>/dev/null; then
    backup="${target}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$target" "$backup"
    chown "$uid:$gid" "$backup"
    chmod 600 "$backup"
    echo "Backed up to: $backup"
  fi

  cp "$source" "$target"
  chown "$uid:$gid" "$target"
  chmod 600 "$target"
  echo "Synced kubeconfig to $target"
else
  echo "Kubeconfig already up to date"
fi
