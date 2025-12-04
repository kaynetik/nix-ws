{ config, pkgs, ... }:

{
  #--
  # SSH Hardening Configuration
  #--

  services.openssh = {
    enable = true;

    # Change SSH port from default 22 to 2337
    ports = [ 2337 ];

    # Hardened SSH settings
    settings = {
      #--
      ## Authentication Settings
      #--

      # Disable password authentication - ONLY allow SSH keys
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;

      # Enable public key authentication
      PubkeyAuthentication = true;

      # Disable root login via SSH
      PermitRootLogin = "no";

      # Restrict SSH access to specific users
      AllowUsers = [ "kayws" ];
      # AllowGroups = [ "sshusers" ];

      #--
      ## Connection Security Settings
      #--

      # Maximum number of authentication attempts per connection
      MaxAuthTries = 3;

      # Time limit for successful authentication (in seconds)
      LoginGraceTime = 20;

      # Maximum number of concurrent unauthenticated connections
      # Format: "start:rate:full" (e.g., "3:50:10" = start at 3, rate 50/min, max 10)
      MaxStartups = "3:50:10";

      # Disable empty passwords
      PermitEmptyPasswords = false;

      #--
      # Protocol and Cipher Settings
      #--

      # Use only SSH protocol version 2 (disable legacy v1)
      Protocol = 2;

      # Disable weak ciphers (tbd testing)
      # Ciphers = "chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com";
      # Disable weak MAC algorithms (tbd testing)
      # MACs = "hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com";

      #--
      # Forwarding and Tunneling (Security Hardening)
      #--

      # Disable X11 forwarding
      X11Forwarding = false;
      # Disable agent forwarding
      AllowAgentForwarding = false;

      #--
      # Logging and Monitoring
      #--

      # Verbose logging for security monitoring
      LogLevel = "VERBOSE";

      #--
      # Connection Management
      #--

      # Client alive interval (send keepalive every 300 seconds)
      ClientAliveInterval = 300;

      # Maximum number of client alive messages without response
      ClientAliveCountMax = 3;

      # Compression (disable for security - can help with timing attacks)
      Compression = false;

      #--
      # Banner and Message Settings
      #--

      # Display a banner message (TODO: create /etc/ssh/banner)
      # Banner = "/etc/ssh/banner";

      #--
      # Additional Security Settings
      #--

      # Ignore .rhosts files
      IgnoreRhosts = true;

      # Disable host-based authentication
      HostbasedAuthentication = false;

      # Disable rhosts-based authentication
      RhostsRSAAuthentication = false;

      # Disable GSSAPI authentication
      GSSAPIAuthentication = false;

      # Strict modes (check file permissions)
      StrictModes = true;

      # Print last login information
      PrintLastLog = true;
      PrintMotd = true;
    };

    #--
    # Host Keys
    #--

    # Note: Generate host keys if they don't exist
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];

    #--
    # Extra Configuration (TODO: Validate what's needed)
    #--

    # Additional OpenSSH config lines (advanced)
    # extraConfig = ''
    #   Match User restricted-user
    #     AllowTcpForwarding no
    #     X11Forwarding no
    # '';
  };

  #--
  # Firewall Configuration
  #--

  networking.firewall = {
    enable = true;

    # Allow SSH on port 2337
    allowedTCPPorts = [ 2337 ];

    # TODO: restrict SSH to specific IP addresses/networks
    # Uncomment and modify if you want to restrict access:
    # allowedTCPPortRanges = [
    #   { from = 2337; to = 2337; }
    # ];

    # Log dropped packets (useful for monitoring)
    logRefusedConnections = true;

    # Log accepted connections (optional, can be verbose)
    # logRefusedUnicastsOnly = false;
  };

  #--
  # Declarative SSH Authorized Keys
  #--

  # Configure SSH public keys declaratively
  users.users.kayws = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ/hmDdXBcIo6Vd5UwHo62naWRojukmy5R1nAOt5tLbs aleksandar@nesovic.dev"
    ];
  };

  #--
  # Optional: Fail2Ban for Brute Force Protection
  #--

  # Uncomment to enable Fail2Ban (protects against brute force attacks)
  # services.fail2ban = {
  #   enable = true;
  #   jails = {
  #     sshd = ''
  #       enabled = true
  #       port = 2337
  #       filter = sshd
  #       logpath = /var/log/auth.log
  #       maxretry = 3
  #       bantime = 3600
  #     '';
  #   };
  # };

  #--
  # Optional: Rate Limiting with nftables
  #--

  # If you want more advanced rate limiting, you can use nftables rules
  # networking.nftables.ruleset = ''
  #   table inet filter {
  #     chain input {
  #       type filter hook input priority 0;
  #       tcp dport 2337 ct state new limit rate 3/minute burst 5 packets accept
  #     }
  #   }
  # '';
}
