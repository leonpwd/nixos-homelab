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

  # leon and hugo share one $HOME (/home/lego — kept as-is, not moved, to
  # avoid relocating existing data) and one login config. uid pinned to 1000
  # to match existing file ownership (tmpfiles rules, container volumes
  # already chowned 1000:1000) that predates this rename from "lego".
  users.users.leon = {
    isNormalUser = true;
    uid          = 1000;
    home         = "/home/lego";
    extraGroups  = [ "wheel" "podman" ];
    shell        = pkgs.zsh;
    hashedPassword = "!";
    homeMode     = "770"; # group "users" (both leon and hugo) gets access
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKTaIJwfMzeyqnMvwonVwqX77OXzqUrlumj8Fl0AOfCX git.staleness589@passmail.com" # Léon
    ];
  };

  # Separate login so sudo/auth logs attribute to the right person, not just
  # the SSH key used to connect. Shares leon's $HOME and shell config on
  # purpose — same rights too: Hugo already has unrestricted sudo either
  # way, this is for accountability, not an access boundary.
  users.users.hugo = {
    isNormalUser = true;
    home         = "/home/lego";
    createHome   = false;
    extraGroups  = [ "wheel" "podman" ];
    shell        = pkgs.zsh;
    hashedPassword = "!";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEsR+Vr5t1fxFlTBNi9eoGIYBkG7uhP/Kg63Z901eKat nathaniel@XPS" # Hugo
    ];
  };

  users.users.root.hashedPassword = "!";

  # ── Shell — Zsh + Starship ─────────────────────────────────────────────────────

  environment.shells = [ pkgs.zsh ];

  # Shared $HOME needs exactly one .zshrc stub (skips zsh's first-run
  # wizard); the rest of the shell experience (completion, p10k, fastfetch)
  # is system-wide below, so leon and hugo get it identically for free.
  system.activationScripts.sharedZshrc = lib.stringAfter [ "users" ] ''
    if [ ! -f /home/lego/.zshrc ]; then
      install -o leon -g users -m 644 /dev/null /home/lego/.zshrc
    fi
  '';

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;

    histSize = 50000;
    histFile = "$HOME/.zsh_history";
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
      fastfetch --config /etc/fastfetch/config.jsonc
    '';
  };

  programs.starship.enable = true;
  environment.etc."starship.toml".source = ./etc/starship.toml;
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

  # ── Network & Firewall Base ────────────────────────────────────────────────────
  
  networking.nameservers = [
    "1.1.1.1"              # Cloudflare Primary
    "1.0.0.1"              # Cloudflare Backup
    "2606:4700:4700::1111"  # Cloudflare IPv6 Primary
  ];   
  
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 
      41641 # Tailscale
    ];
    checkReversePath = "loose";
  };

  # Enable container name DNS for all Podman networks
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  # ── Kernel Hardening (sysctl) ──────────────────────────────────────────────────

  boot.kernel.sysctl = {
    # Memory & Swap optimization for zram
    "vm.swappiness"                               = 180;  # Aggressive zram swapping (official kernel recommendation)

    # Kernel panic auto-reboot (headless VM resilience)
    "kernel.panic"                                = 10;   # Auto-reboot after 10s on kernel panic
    "kernel.panic_on_oops"                        = 1;

    # TCP BBR congestion control & Fair Queueing
    "net.core.default_qdisc"                      = "fq";
    "net.ipv4.tcp_congestion_control"             = "bbr";
    "net.core.rmem_max"                           = 4194304; # 4 MB max receive buffer for high-throughput
    "net.core.wmem_max"                           = 4194304; # 4 MB max send buffer for high-throughput

    # Filesystem protections
    "fs.protected_fifos"                          = 2;    # Prevent FIFO race conditions in world-writable dirs
    "fs.protected_regular"                        = 2;    # Prevent writes to files owned by others in shared dirs
    "fs.suid_dumpable"                            = 0;    # Disable core dumps for SUID processes (no memory leak)

    # Kernel hardening
    "dev.tty.ldisc_autoload"                      = 0;    # Prevent auto-loading of unused TTY line disciplines
    "kernel.kptr_restrict"                        = 2;    # Hide kernel pointers even from root (defeats ASLR bypass)
    "kernel.sysrq"                                = 0;    # Disable Magic SysRq key (useless on headless servers)
    "kernel.unprivileged_bpf_disabled"            = 1;    # Prevent unprivileged BPF (many CVEs) — root Podman unaffected

    # BPF JIT hardening
    "net.core.bpf_jit_harden"                     = 2;    # Harden BPF JIT against constant-blinding attacks

    # Network: anti-spoofing & logging
    "net.ipv4.conf.all.log_martians"              = 1;    # Log packets with impossible source IPs (detect spoofing)
    "net.ipv4.conf.all.send_redirects"            = 0;    # Don't send ICMP redirects (we're not a router)
    "net.ipv4.conf.default.accept_redirects"      = 0;    # Reject incoming ICMP redirects (MITM prevention)
    "net.ipv4.conf.default.log_martians"          = 1;    # Same as above for new interfaces (Podman veth)
    "net.ipv6.conf.all.accept_redirects"          = 0;    # Reject ICMPv6 redirects
    "net.ipv6.conf.default.accept_redirects"      = 0;    # Same for new IPv6 interfaces
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

  environment.systemPackages = with pkgs; [ git vim tailscale fastfetch just tree btop ncdu jq bind.dnsutils lsof eza bat ];

  system.activationScripts.serverJustfile = lib.stringAfter [ "users" ] ''
    install -m 644 ${./etc/server.just} /Justfile
  '';

  system.stateVersion = "26.05";
}
