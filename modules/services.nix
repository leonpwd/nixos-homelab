{ config, lib, pkgs, ... }:
{
  # ── Weekly NixOS Auto-Upgrade — Mondays 04:00 AM ──────────────────────────────

  system.autoUpgrade = {
    enable             = true;
    flake              = "github:leonpwd/nixos-homelab#${config.networking.hostName}";
    flags              = [
      "--no-write-lock-file"
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
      for attempt in 1 2 3; do
        if podman auto-update; then
          exit 0
        fi
        echo "podman auto-update failed (attempt $attempt/3), retrying in 30s..."
        sleep 30
      done
      exit 1
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
