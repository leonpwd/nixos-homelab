{ config, lib, pkgs, ... }:
{
  # ── Mise à jour hebdomadaire — lundi 4h00 ─────────────────────────────────────

  system.autoUpgrade = {
    enable             = true;
    flake              = "path:/etc/nixos#nginx";
    dates              = "Mon 04:00";
    randomizedDelaySec = "30min";
    persistent         = true;
    allowReboot        = false;
  };

  # ── Nettoyage générations — lundi 5h00 ────────────────────────────────────────
  # Garde les 3 dernières générations, supprime le reste, lance le GC.

  systemd.services.nixos-cleanup = {
    description = "Nettoyage des anciennes générations NixOS";
    after       = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --list-generations
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations +3
      ${pkgs.nix}/bin/nix-store --gc
      ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --list-generations
    '';
  };

  systemd.timers.nixos-cleanup = {
    wantedBy  = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "Mon 05:00";
      Persistent         = true;
      RandomizedDelaySec = "15min";
    };
  };
}
