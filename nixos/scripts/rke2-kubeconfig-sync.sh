#!/usr/bin/env bash
# Sync RKE2 kubeconfig to user home directory
# This script is called by systemd service rke2-kubeconfig

set -euo pipefail

SOURCE="/etc/rancher/rke2/rke2.yaml"
USER_HOME="/home/kayws"
KUBE_DIR="$USER_HOME/.kube"
TARGET="$KUBE_DIR/config"

# Get user UID/GID using id command
USER_UID=$(id -u kayws 2>/dev/null || echo "")
USER_GID=$(id -g kayws 2>/dev/null || echo "")

if [ -z "$USER_UID" ] || [ -z "$USER_GID" ]; then
  echo "Error: User kayws not found, skipping kubeconfig sync"
  exit 0
fi

# Wait for source kubeconfig to be created (max 60 seconds)
timeout=60
elapsed=0
while [ ! -f "$SOURCE" ] && [ $elapsed -lt $timeout ]; do
  sleep 1
  elapsed=$((elapsed + 1))
done

if [ ! -f "$SOURCE" ]; then
  echo "Warning: RKE2 kubeconfig not found after $timeout seconds, skipping sync"
  exit 0
fi

echo "Source kubeconfig found: $SOURCE"
ls -la "$SOURCE"

# Create .kube directory if it doesn't exist, or fix permissions if wrong
if [ ! -d "$KUBE_DIR" ]; then
  mkdir -p "$KUBE_DIR"
fi
# Always ensure correct ownership and permissions (fixes permission issues)
chown "$USER_UID:$USER_GID" "$KUBE_DIR"
chmod 700 "$KUBE_DIR"

# Only update if source is newer or target doesn't exist (idempotent)
# This prevents overwriting user's custom kubeconfig during upgrades
if [ ! -f "$TARGET" ] || [ "$SOURCE" -nt "$TARGET" ] || ! cmp -s "$SOURCE" "$TARGET" 2>/dev/null; then
  # Backup existing config if it exists and is different (upgrade safety)
  if [ -f "$TARGET" ] && ! cmp -s "$SOURCE" "$TARGET" 2>/dev/null; then
    BACKUP="$TARGET.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up existing kubeconfig to $BACKUP"
    cp "$TARGET" "$BACKUP"
    chown "$USER_UID:$USER_GID" "$BACKUP"
    chmod 600 "$BACKUP"
  fi

  # Copy kubeconfig
  cp "$SOURCE" "$TARGET"
  chown "$USER_UID:$USER_GID" "$TARGET"
  chmod 600 "$TARGET"
  echo "Kubeconfig synced successfully to $TARGET"
  ls -la "$TARGET"
else
  echo "Kubeconfig already up to date, skipping"
  ls -la "$TARGET"
fi
