#!/usr/bin/env bash
# Apply RKE2 manifests after cluster is ready
# This script is called by systemd service rke2-apply-manifests

set -euo pipefail

# RKE2 reads manifests from /var/lib, but NixOS places them in /etc
# We need to check both locations and copy from /etc to /var/lib if needed
ETC_MANIFEST_DIR="/etc/rancher/rke2/server/manifests"
VAR_MANIFEST_DIR="/var/lib/rancher/rke2/server/manifests"
KUBECTL="/var/lib/rancher/rke2/bin/kubectl"

# Ensure /var/lib manifest directory exists
mkdir -p "$VAR_MANIFEST_DIR"

# Copy user manifests from /etc to /var/lib (where RKE2 actually reads them)
# This ensures manifests are available even if added after RKE2 startup
if [ -d "$ETC_MANIFEST_DIR" ]; then
  echo "Copying user manifests from $ETC_MANIFEST_DIR to $VAR_MANIFEST_DIR"
  for manifest in "$ETC_MANIFEST_DIR"/*.yaml "$ETC_MANIFEST_DIR"/*.yml; do
    if [ -f "$manifest" ]; then
      # Skip HelmChartConfig files - RKE2 handles these automatically from /etc
      if grep -q "kind: HelmChartConfig" "$manifest" 2>/dev/null; then
        continue
      fi
      cp -f "$manifest" "$VAR_MANIFEST_DIR/"
      echo "Copied: $(basename "$manifest")"
    fi
  done
fi

# Wait for RKE2 service to be active first
echo "Waiting for RKE2 service to be active..."
timeout=60
elapsed=0
while ! systemctl is-active --quiet rke2-server.service && [ $elapsed -lt $timeout ]; do
  sleep 2
  elapsed=$((elapsed + 2))
done

if ! systemctl is-active --quiet rke2-server.service; then
  echo "Error: RKE2 service is not active after $timeout seconds"
  exit 1
fi

# Wait for kubectl to be available (max 180 seconds - RKE2 can take time to fully start)
echo "Waiting for Kubernetes API to be ready..."
timeout=180
elapsed=0
while ! "$KUBECTL" cluster-info &>/dev/null && [ $elapsed -lt $timeout ]; do
  sleep 3
  elapsed=$((elapsed + 3))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "Still waiting for API... (${elapsed}s/${timeout}s)"
  fi
done

if ! "$KUBECTL" cluster-info &>/dev/null; then
  echo "Error: Kubernetes API not available after $timeout seconds"
  exit 1
fi

echo "Kubernetes API is ready, applying manifests from $VAR_MANIFEST_DIR"

# Apply all user manifests (skip RKE2 built-in manifests and HelmChartConfig files)
for manifest in "$VAR_MANIFEST_DIR"/*.yaml "$VAR_MANIFEST_DIR"/*.yml; do
  if [ -f "$manifest" ]; then
    # Skip RKE2 built-in manifests (they start with rke2-)
    if [[ "$(basename "$manifest")" == rke2-* ]]; then
      echo "Skipping RKE2 built-in manifest: $(basename "$manifest")"
      continue
    fi

    # Skip HelmChartConfig files - RKE2 handles these automatically
    if grep -q "kind: HelmChartConfig" "$manifest" 2>/dev/null; then
      echo "Skipping HelmChartConfig: $(basename "$manifest") (handled by RKE2)"
      continue
    fi

    echo "Applying manifest: $(basename "$manifest")"
    if "$KUBECTL" apply -f "$manifest"; then
      echo "Successfully applied: $(basename "$manifest")"
    else
      echo "Warning: Failed to apply $manifest (may already exist)"
    fi
  fi
done

echo "Manifest application complete"
