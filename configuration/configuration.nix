{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
    ./secrets.nix
    ./containers.nix
    ./console.nix
  ];

  # ── Système de base ────────────────────────────────────────────────────────────

  networking.hostName = "nginx";
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = false;

  # ── Nix ────────────────────────────────────────────────────────────────────────

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users  = [ "root" ];
    allowed-users  = [ "root" "@wheel" ];
  };

  # ── Utilisateurs ───────────────────────────────────────────────────────────────

  users.mutableUsers = false;

  users.users.lego = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "podman" ];
    shell        = pkgs.zsh;
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILw0xxAKSAbc5PMZncFMBUF7aNxqJAXRaClQgtLq+KOG lego@server"
    ];
  };

  users.users.root.hashedPassword = "!";

  # ── Shell — zsh + Powerlevel10k ────────────────────────────────────────────────

  environment.shells = [ pkgs.zsh ];

  system.activationScripts.legoZshrc = lib.stringAfter [ "users" ] ''
    if [ ! -f /home/lego/.zshrc ]; then
      install -o lego -g users -m 644 /dev/null /home/lego/.zshrc
    fi
  '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    shellInit = ''
      if [[ "$TERM" == "xterm-ghostty" ]]; then export TERM=xterm-256color; fi
    '';

    promptInit = ''
      typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';

    interactiveShellInit = ''
      [[ ! -f /etc/p10k.zsh ]] || source /etc/p10k.zsh
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      alias ls='ls --color=auto'
      alias ll='ls -alF --color=auto'
      alias la='ls -A --color=auto'
      alias docker='podman'
      fastfetch --config /etc/fastfetch/config.jsonc
    '';
  };

  environment.etc."p10k.zsh".source               = ./etc/p10k;
  environment.etc."fastfetch/config.jsonc".source  = ./etc/fastfetch.jsonc;

  # ── Sudo ───────────────────────────────────────────────────────────────────────

  security.sudo = {
    enable           = true;
    execWheelOnly    = true;
    wheelNeedsPassword = false;
    extraConfig = ''
      Defaults env_reset
      Defaults env_keep += "LANG LANGUAGE LINGUAS LC_* _XKB_CHARSET"
      Defaults timestamp_timeout=5
    '';
  };

  # ── SSH ────────────────────────────────────────────────────────────────────────

  services.openssh = {
    enable = true;
    settings = {
      AllowUsers                  = [ "lego" ];
      AuthenticationMethods       = "publickey";
      PasswordAuthentication      = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords        = false;
      PermitRootLogin             = "no";
      MaxAuthTries                = 3;
      LoginGraceTime              = 20;
      MaxSessions                 = 5;
      ClientAliveInterval         = 300;
      ClientAliveCountMax         = 2;
      X11Forwarding               = false;
      AllowAgentForwarding        = false;
      AllowTcpForwarding          = false;
      PrintMotd                   = false;
      PrintLastLog                = false;
    };
    openFirewall = false;
  };

  # ── Réseau & firewall ──────────────────────────────────────────────────────────
  
  networking.nameservers = [
    "1.1.1.1"             # Cloudflare Primary
    "1.0.0.1"             # Cloudflare Backup
    "1.1.1.2"             # Cloudflare Security (Anti-malware)
    "8.8.8.8"             # Google Primary
    "2606:4700:4700::1111" # Cloudflare IPv6 Primary
    "2606:4700:4700::1001" # Cloudflare IPv6 Backup
    "2606:4700:4700::1112" # Cloudflare IPv6 Security
    "2001:4860:4860::8888" # Google IPv6 Primary
  ];   
  
  networking.firewall = {
  enable = true;
  
  # Ports globaux
  allowedUDPPorts = [ 
    41641 # Tailscale
  ];

  # Règles spécifiques par interface réseau
  interfaces = {
    # Interface publique (Internet / LAN)
    ens18 = {
      allowedTCPPorts = [ 22 80 443 81 ];
      allowedUDPPorts = [ 80 443 ];
    };

    # Interface Tailscale (Réseau privé sécurisé)
    tailscale0 = {
      allowedTCPPorts = [ 22 ];
    };
  };

  checkReversePath = "loose";
};


  # ── Services ───────────────────────────────────────────────────────────────────

  services.tailscale.enable = true;

  virtualisation.podman = {
    enable       = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  systemd.sockets.podman = {
    wantedBy = [ "sockets.target" "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;
  };

  systemd.services.podman = {
    wantedBy = [ "multi-user.target" ];
  };

  virtualisation.containers.enable = true;

  # ── Paquets & scripts ──────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [ git vim tailscale fastfetch just tree];

  system.activationScripts.serverJustfile = lib.stringAfter [ "users" ] ''
    install -m 644 ${./etc/server.just} /Justfile
  '';

  system.stateVersion = "26.05";
}
