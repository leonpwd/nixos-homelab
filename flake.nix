{
  description = "Multi-host NixOS Infrastructure (Proxy & Media)";

  inputs = {
    nixpkgs.url  = "github:NixOS/nixpkgs/nixos-26.05";

    # sops-install-secrets is a Go program not in the binary cache: it must never be
    # recompiled by a routine nixpkgs update. Pinned (sops-nix + its own nixpkgs) and
    # used through sops.package in each host's secrets.nix. To update, bump both
    # revisions together.
    nixpkgs-sops.url = "github:NixOS/nixpkgs/cd4ea8d57de16f4810bc5f14207bac45fbf19f67";
    sops-nix.url = "github:Mic92/sops-nix/b18e01ce148eb3efff5de2f2d3181ca53b2b2a54";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-sops";

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
            targetUser = "leon";
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
