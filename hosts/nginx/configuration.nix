{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/base.nix
    ../../modules/services.nix
    ./secrets.nix
    ./hardware-configuration.nix
    ./containers.nix
  ];

  networking.hostName = "nginx";

  environment.etc."fastfetch/config.jsonc".source = ./fastfetch.jsonc;

  # Specific firewall rules for Proxy host (WAN/LAN HTTP/HTTPS ports)
  networking.firewall.interfaces = {
    ens18 = {
      allowedTCPPorts = [ 22 80 443 81 ];
      allowedUDPPorts = [ 80 443 ];
    };
    tailscale0 = {
      allowedTCPPorts = [ 22 ];
    };
  };
  
  environment.etc."issue".text = lib.mkForce ''
    ░   ░░░  ░░░      ░░░        ░░   ░░░  ░░  ░░░░  ░░░      ░░░░      ░░
    ▒    ▒▒  ▒▒  ▒▒▒▒▒▒▒▒▒▒▒  ▒▒▒▒▒    ▒▒  ▒▒▒  ▒▒  ▒▒▒  ▒▒▒▒  ▒▒  ▒▒▒▒▒▒▒
    ▓  ▓  ▓  ▓▓  ▓▓▓   ▓▓▓▓▓  ▓▓▓▓▓  ▓  ▓  ▓▓▓▓    ▓▓▓▓  ▓▓▓▓  ▓▓▓      ▓▓
    █  ██    ██  ████  █████  █████  ██    ███  ██  ███  ████  ████████  █
    █  ███   ███      ███        ██  ███   ██  ████  ███      ████      ██
                    
                  NPMPlus • CrowdSec • AppSec 
  '';
}
