# NixOS Configuration

NixOS configuration for ksvhost.

## Setup

```bash
# Clone repo
git clone git@github.com:kaynetik/nix-ws.git ~/nixos-config

# Backup existing config
sudo mv /etc/nixos /etc/nixos.backup.$(date +%Y%m%d_%H%M%S)

# Create symlink
sudo ln -s ~/nixos-config/nixos /etc/nixos

# Set permissions (user-owned for git operations, root can read via symlink)
sudo chown -R kayws:users ~/nixos-config
chmod 600 ~/nixos-config/nixos/secrets.nix

# Create secrets (if needed)
cp ~/nixos-config/nixos/secrets.nix.example ~/nixos-config/nixos/secrets.nix
nano ~/nixos-config/nixos/secrets.nix  # Fill in secrets
chmod 600 ~/nixos-config/nixos/secrets.nix

# Test and apply
sudo nixos-rebuild dry-run
sudo nixos-rebuild test  # Test without switching (deleted on reboot)
sudo nixos-rebuild switch
```

## Workflow

**Development (macOS):**
```bash
git add nixos/
git commit -m "feat: update config"
git push
```

**NixOS system:**
```bash
cd ~/nixos-config && git pull && sudo nixos-rebuild switch
```

**Note:** If you get permission errors, fix ownership:
```bash
sudo chown -R kayws ~/nixos-config
git config --global --add safe.directory ~/nixos-config
```

## Secrets

- `secrets.nix` is gitignored (never commit)
- Copy from `secrets.nix.example` and fill in values
- Can override with env vars: `RKE2_TOKEN`, `RKE2_IP`

## Files

- `configuration.nix` - Main config (imports others)
- `hardware-configuration.nix` - Hardware settings (never change this manually)
- `ssh-config.nix` - SSH hardening (port 2337, key-only)
- `rke2-config.nix` - RKE2 Kubernetes config
- `secrets.nix` - Sensitive data (gitignored)

## Pre-commit

```bash
pre-commit install
```

Hooks: formatting, syntax check, security scan, conventional commits.
