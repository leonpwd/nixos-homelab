{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./services.nix
    ./secrets.nix
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
      fastfetch --config /etc/fastfetch/config.jsonc
    '';
  };

  environment.etc."p10k.zsh".source          = ./p10k.zsh;
  environment.etc."fastfetch/config.jsonc".source = ./fastfetch.jsonc;

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

  networking.firewall = {
    enable           = true;
    allowedUDPPorts  = [ 41641 ];
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    interfaces.ens18.allowedTCPPorts      = [ 22 ];
    checkReversePath = "loose";
  };

  # ── Services ───────────────────────────────────────────────────────────────────

  services.tailscale.enable = true;

  virtualisation.podman = {
    enable       = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.containers.enable = true;

  # ── Paquets & scripts ──────────────────────────────────────────────────────────

  environment.systemPackages = with pkgs; [ git vim tailscale fastfetch just ];

  system.activationScripts.serverJustfile = lib.stringAfter [ "users" ] ''
    install -o lego -g users -m 644 ${./server.just} /home/lego/Justfile
  '';

  system.stateVersion = "26.05";
}
