{
  description = "Base NixOS server with Tailscale and Podman";

  inputs = {
    nixpkgs.url  = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, sops-nix, ... }:
    let
      system = "x86_64-linux";
    in {
      nixosConfigurations.nginx = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          sops-nix.nixosModules.sops
          ./configuration/configuration.nix
        ];
      };
    };
}
