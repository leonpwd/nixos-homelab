{ config, lib, pkgs, inputs, ... }:
{
  # ── Base System ───────────────────────────────────────────────────────────────

  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  i18n.supportedLocales = [
    "fr_FR.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];

  zramSwap.enable = true;
  services.fstrim.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.graceful = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.tmp.cleanOnBoot = true;

  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = false;

  # ── Nix ────────────────────────────────────────────────────────────────────────

  nix.channel.enable = false;

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users  = [ "root" ];
    allowed-users  = [ "root" "@wheel" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # ── Users ──────────────────────────────────────────────────────────────────────

  users.mutableUsers = false;

  users.groups.lego = {};

  users.users.leon = {
    isNormalUser = true;
    uid          = 1000;
    home         = "/home/lego";
    extraGroups  = [ "lego" "wheel" "podman" ];
    shell        = pkgs.zsh;
    hashedPassword = "!";
    homeMode     = "2770";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKTaIJwfMzeyqnMvwonVwqX77OXzqUrlumj8Fl0AOfCX git.staleness589@passmail.com"
    ];
  };

  users.users.hugo = {
    isNormalUser = true;
    home         = "/home/lego";
    createHome   = false;
    extraGroups  = [ "lego" "wheel" "podman" ];
    shell        = pkgs.zsh;
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEsR+Vr5t1fxFlTBNi9eoGIYBkG7uhP/Kg63Z901eKat nathaniel@XPS"
    ];
  };

  users.users.root.hashedPassword = "!";

  # ── Shell — Zsh + Starship ─────────────────────────────────────────────────────

  environment.shells = [ pkgs.zsh ];

  system.activationScripts.sharedZshrc = lib.stringAfter [ "users" ] ''
    if [ ! -f /home/lego/.zshrc ]; then
      install -o leon -g lego -m 644 /dev/null /home/lego/.zshrc
    fi
    if [ -f /home/lego/.zsh_history ] && [ ! -f /home/lego/.zsh_history_leon ]; then
      mv /home/lego/.zsh_history /home/lego/.zsh_history_leon
    fi
    chgrp -R lego /home/lego
    chmod -R g+rwX /home/lego
    find /home/lego -type d -exec chmod g+s {} +
  '';

  programs.zsh.shellInit = "umask 002";

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    histSize = 50000;
    histFile = "$HOME/.zsh_history_$USER";
    setOptions = [
      "EXTENDED_HISTORY"
      "HIST_EXPIRE_DUPS_FIRST"
      "HIST_IGNORE_DUPS"
      "HIST_IGNORE_ALL_DUPS"
      "HIST_IGNORE_SPACE"
      "HIST_FIND_NO_DUPS"
      "HIST_SAVE_NO_DUPS"
      "HIST_FCNTL_LOCK"
      "SHARE_HISTORY"
    ];

    interactiveShellInit = ''
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down
      alias ls='eza --icons=auto --group-directories-first'
      alias ll='eza -alF --icons=auto --git --group-directories-first'
      alias la='eza -a --icons=auto --group-directories-first'
      alias lt='eza --tree --level=2 --icons=auto'
      alias docker='podman'
      alias ox='sudo DOCKER_HOST=unix:///run/podman/podman.sock oxker'
      _fastfetch_config=/etc/fastfetch/config.jsonc
      if [[ $TERM == linux ]]; then
        export STARSHIP_CONFIG=/etc/starship-console.toml
        _fastfetch_config=/etc/fastfetch/config-plain.jsonc
        alias ls='eza --group-directories-first'
        alias ll='eza -alF --git --group-directories-first'
        alias la='eza -a --group-directories-first'
        alias lt='eza --tree --level=2'
      fi
      fastfetch --config $_fastfetch_config
    '';
  };

  environment.shellAliases = {
    ls = null;
    ll = null;
  };

  programs.starship.enable = true;
  environment.etc."starship.toml".source = ./etc/starship.toml;
  environment.etc."starship-console.toml".source = ./etc/starship-console.toml;
  environment.etc."fastfetch/config-plain.jsonc".source =
    pkgs.runCommand "fastfetch-plain.jsonc" { nativeBuildInputs = [ pkgs.perl ]; } ''
      perl -CSD -pe 's/[\x{E000}-\x{F8FF}\x{F0000}-\x{10FFFD}]//g' ${config.environment.etc."fastfetch/config.jsonc".source} > $out
    '';
  environment.variables.STARSHIP_CONFIG  = "/etc/starship.toml";

  programs.zoxide.enable = true;
  programs.fzf.keybindings = true;

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
      AllowUsers                  = [ "leon" "hugo" ];
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
      PermitTunnel                = "no";
      LogLevel                    = "VERBOSE";
      PrintMotd                   = false;
      PrintLastLog                = false;
    };
    openFirewall = false;
  };
  
  # ── Logging (Journald) & Systemd Timeouts ─────────────────────────────────────

  services.journald.extraConfig = ''
    SystemMaxUse=200M
    SystemMaxFileSize=50M
  '';

  systemd.settings.Manager = {
    DefaultTimeoutStopSec = "20s";
  };

  systemd.coredump.enable = false;

  # ── Console Proxmox & Auto-Login TTY1 (Nginx Proxy Host) ──────────────────────

  services.getty = {
    autologinUser = "leon";
    helpLine = lib.mkForce "";
    greetingLine = lib.mkForce "";
  };

  boot.kernelParams = [ "console=tty0" "console=ttyS0,115200n8" ];

  systemd.services."serial-getty@ttyS0" = {
    wantedBy = [ "getty.target" ];
    environment.TERM = "xterm-256color";
    serviceConfig.Restart = "always";
    serviceConfig.RestartSec = 1;
    unitConfig.StartLimitIntervalSec = 0;
  };

  # ── Network & Firewall Base ────────────────────────────────────────────────────
  
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
  ];   
  
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 
      41641
    ];
    checkReversePath = "loose";
  };

  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  # ── Kernel Hardening (sysctl) ──────────────────────────────────────────────────

  boot.kernel.sysctl = {
    "vm.swappiness"                               = 180;

    "kernel.panic"                                = 10;
    "kernel.panic_on_oops"                        = 1;

    "net.core.default_qdisc"                      = "fq";
    "net.ipv4.tcp_congestion_control"             = "bbr";
    "net.core.rmem_max"                           = 4194304;
    "net.core.wmem_max"                           = 4194304;

    "fs.protected_fifos"                          = 2;
    "fs.protected_regular"                        = 2;
    "fs.suid_dumpable"                            = 0;

    "dev.tty.ldisc_autoload"                      = 0;
    "kernel.kptr_restrict"                        = 2;
    "kernel.sysrq"                                = 0;
    "kernel.unprivileged_bpf_disabled"            = 1;

    "net.core.bpf_jit_harden"                     = 2;

    "net.ipv4.conf.all.log_martians"              = 1;
    "net.ipv4.conf.all.send_redirects"            = 0;
    "net.ipv4.conf.default.accept_redirects"      = 0;
    "net.ipv4.conf.default.log_martians"          = 1;
    "net.ipv6.conf.all.accept_redirects"          = 0;
    "net.ipv6.conf.default.accept_redirects"      = 0;
  };

  # ── Shared Services (Tailscale, QEMU Guest, EarlyOOM & Podman) ─────────────

  services.tailscale.enable = true;
  services.qemuGuest.enable = true;
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;
  };

  virtualisation.podman = {
    enable       = true;
    dockerCompat = true;
    dockerSocket.enable = true;
    defaultNetwork.settings.dns_enabled = true;
    autoPrune = {
      enable = true;
      flags  = [ "--all" ];
      dates  = "weekly";
    };
  };

  systemd.sockets.podman = {
    wantedBy = [ "sockets.target" "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;
  };

  systemd.services.podman = {
    wantedBy = [ "multi-user.target" ];
  };

  virtualisation.containers.enable = true;

  # ── Base System Packages & Scripts ─────────────────────────────────────────────

  environment.systemPackages = with pkgs; [ git vim tailscale fastfetch just tree btop ncdu jq bind.dnsutils lsof eza bat oxker ];

  system.activationScripts.serverJustfile = lib.stringAfter [ "users" ] ''
    install -m 644 ${./etc/server.just} /Justfile
  '';

  system.stateVersion = "26.05";
}
