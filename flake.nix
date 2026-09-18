{
  description = "Multi-host NixOS Infrastructure (Proxy & Media)";

  inputs = {
    nixpkgs.url  = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, sops-nix, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations = {

        # ── Reverse Proxy & WAF Host (NPMPlus + CrowdSec + Arcane) ─────────────
        nginx = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/nginx/configuration.nix
          ];
        };

        # ── Media & *Arr Stack Host (Jellyfin, Sonarr, Radarr, Prowlarr) ─────────
        media = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/media/configuration.nix
          ];
        };

      };
    };
}
