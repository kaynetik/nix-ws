{ config, pkgs, ... }:

{
  services.rke2 = {
    enable = true;
    role = "server";  # Change to "agent" for worker nodes

    # Specify package version
    package = pkgs.rke2_1_34;

    # CNI selection (default: canal)
    cni = "canal";  # Options: "none", "canal", "cilium", "calico", "flannel"

    # Point to declaratively managed config file
    configPath = "/etc/rancher/rke2/config.yaml";
  };

  # Firewall: Allow RKE2 ports (merged with ssh-config.nix firewall settings)
  # Note: Firewall is already enabled in ssh-config.nix
  networking.firewall.allowedTCPPorts = [
    6443   # Kubernetes API
    9345   # RKE2 server registration
    10250  # Kubelet
    8472   # Flannel VXLAN
    51820  # Flannel WireGuard
  ];
  networking.firewall.allowedUDPPorts = [
    8472   # Flannel VXLAN
    51820  # Flannel WireGuard
  ];

  # NetworkManager: Ignore CNI-managed interfaces
  ## [As the official documentation for RKE2 requires at the time of writing this](https://docs.rke2.io/known_issues#networkmanager)
  networking.networkmanager.unmanaged = [
    "interface-name:cni*"
    "interface-name:flannel*"
    "interface-name:veth*"
    "interface-name:cali*"
    "interface-name:tunl*"
  ];

  # Add RKE2 bin directory to system PATH
  environment.profileRelativeEnvVars = {
    PATH = [ "/var/lib/rancher/rke2/bin" ];
  };

  # Set KUBECONFIG to user's home directory
  # Note: Users need to restart shell or run 'source /etc/profile' after rebuild
  environment.sessionVariables = {
    KUBECONFIG = "/home/kayws/.kube/config";
  };

  # Shell aliases
  programs.zsh.shellAliases = {
    k = "/var/lib/rancher/rke2/bin/kubectl";
    kubectl = "/var/lib/rancher/rke2/bin/kubectl";
  };
  programs.bash.shellAliases = {
    k = "/var/lib/rancher/rke2/bin/kubectl";
    kubectl = "/var/lib/rancher/rke2/bin/kubectl";
  };

  # RKE2 Kubernetes Cluster - Declarative Configuration
  # Generate RKE2 config.yaml declaratively
  # Token is read from secrets file
  environment.etc."rancher/rke2/config.yaml" = let
    # Read token from secrets file (gitignored, but included in flake via filterSource)
    # Fallback to environment variable if file doesn't exist (for CI/CD)
    rke2Token = let
      secretsFile = ./secrets.nix;
      envToken = builtins.getEnv "RKE2_TOKEN";
      secrets = builtins.tryEval (import secretsFile);
    in
      if secrets.success
      then secrets.value.rke2Token
      else if envToken != ""
      then envToken
      else throw "RKE2 token not found. Either create nixos/secrets.nix or set RKE2_TOKEN environment variable.";

    # Read IP address from environment variable first, then secrets file
    # No default fallback - must be explicitly set
    rke2IP = let
      secretsFile = ./secrets.nix;
      envIP = builtins.getEnv "RKE2_IP";
      secrets = builtins.tryEval (import secretsFile);
    in
      if envIP != ""
      then envIP
      else if secrets.success
      then secrets.value.rke2IP or (throw "RKE2_IP not found. Either set RKE2_IP environment variable or add rke2IP to nixos/secrets.nix")
      else throw "RKE2_IP not found. Either set RKE2_IP environment variable or create nixos/secrets.nix with rke2IP";
  in {
    text = ''
      # RKE2 Cluster Configuration (Declaratively Managed)
      token: "${rke2Token}"
      node-name: "ksvhost"
      tls-san:
        - "${rke2IP}"
        - "ksvhost"

      # Disable nginx, enable Traefik
      disable:
        - rke2-ingress-nginx
      ingress-controller: traefik
    '';
    mode = "0600";
  };

  # Service to sync kubeconfig to user's home directory
  # Features:
  # - Uses UID/GID lookup
  # - Idempotent: only updates if source is newer/different
  # - Backs up existing config before overwriting (upgrade-safe)
  # - Handles missing source gracefully
  systemd.services.rke2-kubeconfig = {
    description = "Sync RKE2 kubeconfig to user home directory";
    after = [ "rke2-server.service" ];
    wants = [ "rke2-server.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };
    path = with pkgs; [ coreutils ];
    script = builtins.readFile ./scripts/rke2-kubeconfig-sync.sh;
  };
}
