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

  environment.etc."fastfetch/config.jsonc".source = ./etc/fastfetch.jsonc;

  # Force IPv4 preference for outbound connections (fixes certbot → Cloudflare API
  # with rotating IPv6 privacy extensions causing token rejection)
  environment.etc."gai.conf".text = ''
    precedence ::ffff:0:0/96 100
  '';

  # Reverse Path Filtering — safe on nginx (no complex Podman container routing)
  boot.kernel.sysctl."net.ipv4.conf.all.rp_filter" = 1;

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
