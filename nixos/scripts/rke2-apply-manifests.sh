#!/usr/bin/env bash
set -euo pipefail

etc_dir="/etc/rancher/rke2/server/manifests"
var_dir="/var/lib/rancher/rke2/server/manifests"
kubectl="/var/lib/rancher/rke2/bin/kubectl"
kubeconfig="/etc/rancher/rke2/rke2.yaml"

export KUBECONFIG="$kubeconfig"
mkdir -p "$var_dir"

# Copy user manifests from /etc to /var/lib (RKE2 reads from /var/lib)
manifests=()
if [ -d "$etc_dir" ]; then
  for f in "$etc_dir"/*.yaml "$etc_dir"/*.yml; do
    [ -e "$f" ] || continue
    [ -f "$f" ] || continue

    # Skip HelmChartConfig - RKE2 handles these
    grep -q "kind: HelmChartConfig" "$f" 2>/dev/null && continue

    name=$(basename "$f")
    cp -f "$f" "$var_dir/"
    manifests+=("$var_dir/$name")
    echo "Copied: $name"
  done
fi

# Wait for RKE2 to be ready
for i in {1..30}; do
  systemctl is-active --quiet rke2-server.service && break
  [ $i -eq 30 ] && { echo "RKE2 service not active"; exit 1; }
  sleep 2
done

# Wait for kubeconfig
for i in {1..30}; do
  [ -f "$kubeconfig" ] && break
  [ $i -eq 30 ] && { echo "Kubeconfig not found"; exit 1; }
  sleep 2
done

# Wait for API
for i in {1..60}; do
  "$kubectl" cluster-info &>/dev/null && break
  [ $i -eq 60 ] && { echo "API not ready"; exit 1; }
  sleep 3
done

# Apply manifests
for m in "${manifests[@]}"; do
  [ -f "$m" ] || continue
  echo "Applying: $(basename "$m")"
  "$kubectl" apply -f "$m" || true
done
