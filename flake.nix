{
  description = "Multi-host NixOS Infrastructure (Proxy & Media)";

  inputs = {
    nixpkgs.url  = "github:NixOS/nixpkgs/nixos-26.05";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    colmena.url  = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, sops-nix, colmena, ... }:
    let
      system = "x86_64-linux";
    in {
      colmenaHive = colmena.lib.makeHive self.outputs.colmena;

      colmena = {
        meta = {
          nixpkgs = import nixpkgs { inherit system; };
          specialArgs = { inherit inputs; };
        };

        defaults = { ... }: {
          deployment = {
            targetUser = "lego";
            buildOnTarget = true;
          };
        };

        nginx = { ... }: {
          deployment.targetHost = "nginx";
          imports = [
            sops-nix.nixosModules.sops
            ./hosts/nginx/configuration.nix
          ];
        };

        media = { ... }: {
          deployment.targetHost = "media";
          imports = [
            sops-nix.nixosModules.sops
            ./hosts/media/configuration.nix
          ];
        };
      };

      nixosConfigurations = {

        # ── Reverse Proxy & WAF Host (NPMPlus + CrowdSec + Arcane) ─────────────
        nginx = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/nginx/configuration.nix
          ];
        };

        # ── Media & *Arr Stack Host (Jellyfin, Sonarr, Radarr, Prowlarr) ─────────
        media = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            sops-nix.nixosModules.sops
            ./hosts/media/configuration.nix
          ];
        };

      };
    };
}
