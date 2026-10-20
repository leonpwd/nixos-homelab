{ config, lib, pkgs, ... }:
{
  # ── Weekly NixOS Auto-Upgrade — Mondays 04:00 AM ──────────────────────────────

  system.autoUpgrade = {
    enable             = true;
    flake              = "path:/etc/nixos#${config.networking.hostName}";
    flags              = [
      "--update-input"
      "nixpkgs"
    ];
    dates              = "Mon 04:00";
    randomizedDelaySec = "30min";
    persistent         = true;
    allowReboot        = true;
    rebootWindow = {
      lower = "04:00";
      upper = "06:00";
    };
  };

  # ── Podman Container Auto-Update — Daily at 04:00 AM ───────────────────────────
  # Updates containers tagged io.containers.autoupdate=registry.

  systemd.services.podman-auto-update = {
    description = "Auto-update Podman containers";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    path        = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      podman auto-update
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
