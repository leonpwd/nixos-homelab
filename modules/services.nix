{ config, lib, pkgs, ... }:
{
  # ── Weekly NixOS Auto-Upgrade — Mondays 04:00 AM ──────────────────────────────

  system.autoUpgrade = {
    enable             = true;
    flake              = "path:/etc/nixos#${config.networking.hostName}";
    flags              = [ "--update-input" "nixpkgs" ];
    dates              = "Mon 04:00";
    randomizedDelaySec = "30min";
    persistent         = true;
    allowReboot        = true;
    rebootWindow = {
      lower = "05:00";
      upper = "06:00";
    };
  };

  # ── NixOS Generation Cleanup — Mondays 05:00 AM ───────────────────────────────
  # Retains the 3 latest generations, purges old generations, runs garbage collector.

  systemd.services.nixos-cleanup = {
    description = "Cleanup old NixOS system generations";
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

  # ── Podman Container Auto-Update — Daily at 04:00 AM ───────────────────────────
  # Updates containers tagged io.containers.autoupdate=registry and prunes dangling images.

  systemd.services.podman-auto-update = {
    description = "Auto-update Podman containers and prune images";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    path        = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      podman auto-update
      podman image prune -a -f
      podman container prune -f
    '';
  };

  systemd.timers.podman-auto-update = {
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "*-*-* 04:00:00";
      Persistent         = true;
      RandomizedDelaySec = "10min";
    };
  };
}
