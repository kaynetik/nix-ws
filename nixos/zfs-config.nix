{ config, lib, pkgs, ... }:

{
  #--
  # ZFS Configuration
  #--

  # Enable ZFS support
  boot.supportedFilesystems = [ "zfs" ];

  # Don't force import root pool (we're not using ZFS for root)
  boot.zfs.forceImportRoot = false;
  # Auto-import the ksvpool on boot
  boot.zfs.extraPools = [ "ksvpool" ];

  # Enable ZFS services
  services.zfs = {
    # Auto-scrub pools weekly (data integrity check)
    autoScrub.enable = true;
    autoScrub.interval = "weekly";

    # Auto-snapshot datasets (optional, can be configured per dataset)
    # autoSnapshot.enable = true;
  };

  # Install ZFS utilities
  environment.systemPackages = with pkgs; [
    zfs
    gptfdisk
    util-linux
  ];

  # Systemd service to set up ZFS pool and dataset
  # This service runs ONCE - it will only create the pool if it doesn't exist
  # After the pool is created and the setup flag is set, it won't run again
  # This prevents accidental recreation of pools with data
  systemd.services.zfs-setup = {
    description = "Set up ZFS pool and datasets (runs once)";
    wantedBy = [ "multi-user.target" ];
    # Wait for ZFS modules to be loaded and import cache to be ready
    after = [ "zfs-import-cache.service" "systemd-modules-load.service" ];
    wants = [ "zfs-import-cache.service" "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      # Ensure ZFS modules are loaded before running the script
      ExecStartPre = "${pkgs.kmod}/bin/modprobe zfs";
    };
    path = with pkgs; [
      zfs
      kmod  # for modprobe
      coreutils
    ];
    script = builtins.readFile ./scripts/zfs-setup.sh;
  };

  # Optional: Mount the media dataset at a specific location
  # Uncomment and adjust if you want a specific mountpoint
  # fileSystems."/mnt/media" = {
  #   device = "ksvpool/media";
  #   fsType = "zfs";
  #   options = [ "zfsutil" ];
  # };
}
