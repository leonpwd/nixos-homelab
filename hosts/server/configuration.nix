
{ config, lib, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "server";
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitEmptyPasswords = true;
      PermitRootLogin = "yes";
    };
    openFirewall = false;
  };

  security.pam.services.sshd.allowNullPassword = true;
  users.users.root.initialHashedPassword = "";

  services.tailscale.enable = true;

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.containers.enable = true;

  networking.firewall = {
    allowedUDPPorts = [ 41641 ];
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    checkReversePath = "loose";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
    tailscale
  ];

  system.stateVersion = "26.05";
}
