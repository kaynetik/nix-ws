{ config, pkgs, ... }:

{
  # RKE2 Kubernetes Cluster - Declarative Configuration
  # Generate RKE2 config.yaml declaratively
  # Token is read from secrets file
  environment.etc."rancher/rke2/config.yaml" = let
    # Read token from secrets file (gitignored)
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
    '';
    mode = "0600";
  };

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
    script = ''
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
    '';
  };

}
