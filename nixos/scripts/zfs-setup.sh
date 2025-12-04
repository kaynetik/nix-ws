#!/usr/bin/env bash
set -euo pipefail

# ZFS Pool Configuration
POOL_NAME="ksvpool"
DATASET_NAME="${POOL_NAME}/media"
DRIVES=("/dev/sda" "/dev/sdb")
SETUP_FLAG="/var/lib/zfs-setup-complete"

# Function to check if pool exists
pool_exists() {
  zpool list -H -o name 2>/dev/null | grep -q "^${POOL_NAME}$" || return 1
}

# Function to check if dataset exists
dataset_exists() {
  zfs list -H -o name 2>/dev/null | grep -q "^${DATASET_NAME}$" || return 1
}

# Main setup logic
main() {
  # Safety check: Only run once if pool already exists and has been set up
  if [ -f "${SETUP_FLAG}" ] && pool_exists; then
    echo "ZFS pool ${POOL_NAME} already exists and setup is complete."
    echo "This script will not run again to prevent data loss."
    echo "If you need to recreate the pool, remove ${SETUP_FLAG} first (DANGEROUS!)."
    exit 0
  fi

  echo "=== ZFS Pool Setup ==="
  echo "Pool: ${POOL_NAME}"
  echo "Dataset: ${DATASET_NAME}"
  echo "Drives: ${DRIVES[*]}"
  echo ""
  echo "WARNING: This script will create a ZFS pool. Make sure drives are wiped clean first!"
  echo ""

  # Check if pool already exists
  if pool_exists; then
    echo "Pool ${POOL_NAME} already exists"
  else
    echo "Creating ZFS pool ${POOL_NAME}..."
    echo "Assuming drives ${DRIVES[*]} are already wiped clean."

    # Create the mirrored pool
    # Using whole disks (not partitions) for better ZFS management
    zpool create -f \
      -o ashift=12 \
      -o autoexpand=on \
      -o autotrim=on \
      "${POOL_NAME}" \
      mirror "${DRIVES[@]}"

    echo "Pool ${POOL_NAME} created successfully"
  fi

  # Check if dataset already exists
  if dataset_exists; then
    echo "Dataset ${DATASET_NAME} already exists"
  else
    echo "Creating ZFS dataset ${DATASET_NAME}..."
    zfs create "${DATASET_NAME}"
    echo "Dataset ${DATASET_NAME} created successfully"
  fi

  # Mark setup as complete
  touch "${SETUP_FLAG}"
  echo "Setup flag created: ${SETUP_FLAG}"

  # Show pool status
  echo ""
  echo "=== Pool Status ==="
  zpool status "${POOL_NAME}" || true

  echo ""
  echo "=== Dataset List ==="
  zfs list -r "${POOL_NAME}" || true

  echo ""
  echo "ZFS setup complete!"
}

main "$@"
