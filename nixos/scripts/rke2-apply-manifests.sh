#!/usr/bin/env bash
# Apply RKE2 manifests after cluster is ready
# This script is called by systemd service rke2-apply-manifests

set -euo pipefail

# RKE2 reads manifests from /var/lib, but NixOS places them in /etc
# We need to check both locations and copy from /etc to /var/lib if needed
ETC_MANIFEST_DIR="/etc/rancher/rke2/server/manifests"
VAR_MANIFEST_DIR="/var/lib/rancher/rke2/server/manifests"
KUBECTL="/var/lib/rancher/rke2/bin/kubectl"
KUBECONFIG="/etc/rancher/rke2/rke2.yaml"

# Export KUBECONFIG for kubectl (systemd runs as root, needs system kubeconfig)
export KUBECONFIG

# Ensure /var/lib manifest directory exists
mkdir -p "$VAR_MANIFEST_DIR"

# Copy user manifests from /etc to /var/lib (where RKE2 actually reads them)
# This ensures manifests are available even if added after RKE2 startup
USER_MANIFESTS=()
if [ -d "$ETC_MANIFEST_DIR" ]; then
  echo "Copying user manifests from $ETC_MANIFEST_DIR to $VAR_MANIFEST_DIR"
  for manifest in "$ETC_MANIFEST_DIR"/*.yaml "$ETC_MANIFEST_DIR"/*.yml; do
    # Handle case where glob doesn't match
    [ -e "$manifest" ] || continue

    if [ -f "$manifest" ]; then
      manifest_name=$(basename "$manifest")
      # Skip HelmChartConfig files - RKE2 handles these automatically from /etc
      if grep -q "kind: HelmChartConfig" "$manifest" 2>/dev/null; then
        echo "Skipping HelmChartConfig during copy: $manifest_name"
        continue
      fi
      cp -f "$manifest" "$VAR_MANIFEST_DIR/"
      USER_MANIFESTS+=("$VAR_MANIFEST_DIR/$manifest_name")
      echo "Copied: $manifest_name"
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

# Wait for kubeconfig file to exist first
echo "Waiting for RKE2 kubeconfig to be created..."
timeout=60
elapsed=0
while [ ! -f "$KUBECONFIG" ] && [ $elapsed -lt $timeout ]; do
  sleep 2
  elapsed=$((elapsed + 2))
done

if [ ! -f "$KUBECONFIG" ]; then
  echo "Error: Kubeconfig not found at $KUBECONFIG after $timeout seconds"
  exit 1
fi

# Wait for kubectl to be available (max 180 seconds - RKE2 can take time to fully start)
echo "Waiting for Kubernetes API to be ready..."
timeout=180
elapsed=0
while ! "$KUBECTL" cluster-info &>/dev/null 2>&1 && [ $elapsed -lt $timeout ]; do
  sleep 3
  elapsed=$((elapsed + 3))
  if [ $((elapsed % 30)) -eq 0 ]; then
    echo "Still waiting for API... (${elapsed}s/${timeout}s)"
    # Show what error we're getting for debugging
    "$KUBECTL" cluster-info 2>&1 | head -1 || true
  fi
done

if ! "$KUBECTL" cluster-info &>/dev/null 2>&1; then
  echo "Error: Kubernetes API not available after $timeout seconds"
  echo "Last error:"
  "$KUBECTL" cluster-info 2>&1 || true
  exit 1
fi

echo "Kubernetes API is ready, applying user manifests"

# Apply user manifests we copied (this ensures we apply them even if RKE2 built-ins are in the same dir)
if [ ${#USER_MANIFESTS[@]} -gt 0 ]; then
  echo "Applying ${#USER_MANIFESTS[@]} user manifest(s):"
  for manifest in "${USER_MANIFESTS[@]}"; do
    if [ -f "$manifest" ]; then
      manifest_name=$(basename "$manifest")
      echo "Applying manifest: $manifest_name"
      if "$KUBECTL" apply -f "$manifest" 2>&1; then
        echo "Successfully applied: $manifest_name"
      else
        echo "Warning: Failed to apply $manifest_name (check errors above)"
      fi
    fi
  done
else
  echo "No user manifests found to apply"
fi

echo "Manifest application complete"
