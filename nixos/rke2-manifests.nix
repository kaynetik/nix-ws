{ config, pkgs, ... }:

{
  # cert-manager via RKE2 manifest auto-apply
  environment.etc."rancher/rke2/server/manifests/cert-manager.yaml" = {
    text = builtins.readFile (builtins.fetchurl {
      url = "https://github.com/cert-manager/cert-manager/releases/download/v1.19.1/cert-manager.yaml";
    });
    mode = "0644";
  };
}
