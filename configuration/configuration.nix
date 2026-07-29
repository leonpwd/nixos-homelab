
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # ---------------------------------------------------------------------------
  # Système de base
  # ---------------------------------------------------------------------------

  networking.hostName = "server";
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = false;

  # ---------------------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------------------

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    # Seul root (ou sudo) peut faire des opérations "trusted" (eval nixpkgs, etc.)
    trusted-users = [ "root" ];
    allowed-users = [ "root" "@wheel" ];
  };

  # ---------------------------------------------------------------------------
  # Gestion des utilisateurs
  # ---------------------------------------------------------------------------

  users.mutableUsers = false;
  users.users.lego = {
    isNormalUser = true;
    extraGroups = [ "wheel" "podman" ];

    # Mot de passe verrouillé : seule la clé SSH permet de se connecter.
    # "!" = compte désactivé pour l'auth par mot de passe.
    hashedPassword = "!";

    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILw0xxAKSAbc5PMZncFMBUF7aNxqJAXRaClQgtLq+KOG lego@server"
    ];
  };

  # Root également verrouillé (pas de login root possible, ni SSH ni console)
  users.users.root.hashedPassword = "!";

  # ---------------------------------------------------------------------------
  # Sudo
  # ---------------------------------------------------------------------------

  security.sudo = {
    enable = true;

    # Seuls les binaires dans les répertoires "sûrs" peuvent être exécutés via sudo.
    # Empêche d'utiliser sudo avec un binaire malveillant dans /tmp etc.
    execWheelOnly = true;
    wheelNeedsPassword = false;

    # Sécurité supplémentaire : efface les variables d'environnement dangereuses
    extraConfig = ''
      Defaults env_reset
      Defaults env_keep += "LANG LANGUAGE LINGUAS LC_* _XKB_CHARSET"
      Defaults timestamp_timeout=5
    '';
  };

  # ---------------------------------------------------------------------------
  # SSH — durci
  # ---------------------------------------------------------------------------

  services.openssh = {
    enable = true;
    settings = {
      # Seul lego peut se connecter
      AllowUsers = [ "lego" ];

      # Clé uniquement
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = false;
      PermitRootLogin = "no";

      # Timeouts et tentatives
      MaxAuthTries = 5;
      LoginGraceTime = 30;
      MaxSessions = 3;

      # Déconnexion si le client est silencieux trop longtemps
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;

      # Désactive les fonctionnalités inutiles côté serveur
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
    };
    # Le port 22 n'est ouvert que sur l'interface Tailscale (voir firewall ci-dessous)
    openFirewall = false;
  };

  # ---------------------------------------------------------------------------
  # Réseau & firewall
  # ---------------------------------------------------------------------------
  # Le port 22 n'est ouvert que sur l'interface Tailscale (voir firewall ci-dessous)
  networking.firewall = {
    enable = true;
    # Port Tailscale WireGuard
    allowedUDPPorts = [ 41641 ];
    # SSH uniquement sur l'interface Tailscale — jamais exposé sur Internet
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    checkReversePath = "loose";
  };

  # ---------------------------------------------------------------------------
  # Services
  # ---------------------------------------------------------------------------

  services.tailscale.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.containers.enable = true;

  # ---------------------------------------------------------------------------
  # Paquets système
  # ---------------------------------------------------------------------------

  environment.systemPackages = with pkgs; [
    git
    vim
    tailscale
  ];

  system.stateVersion = "26.05";
}
