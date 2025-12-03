{ config, pkgs, ... }:

{
  # cert-manager via RKE2 manifest auto-apply
  environment.etc."rancher/rke2/server/manifests/cert-manager.yaml" = {
    text = builtins.readFile (builtins.fetchurl {
      url = "https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml";
    });
    mode = "0644";
  };

  # Service to apply manifests after RKE2 cluster is ready
  # RKE2 only processes manifests at startup, so this ensures manifests
  # are applied even if they're added after RKE2 starts
  systemd.services.rke2-apply-manifests = {
    description = "Apply RKE2 manifests after cluster is ready";
    after = [ "rke2-server.service" ];
    requires = [ "rke2-server.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    path = with pkgs; [ coreutils gnugrep systemd ];
    script = builtins.readFile ./scripts/rke2-apply-manifests.sh;
  };
}
