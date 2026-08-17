{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/base.nix
    ../../modules/services.nix
    ./secrets.nix
    ./hardware-configuration.nix
    ./containers.nix
  ];

  networking.hostName = "media";

  environment.etc."fastfetch/config.jsonc".source = ./etc/fastfetch.jsonc;

  # ── Proxmox VirtioFS Shared Storage ──────────────────────────────────────────

  fileSystems."/media/HDD1" = {
    device = "HDD1";
    fsType = "virtiofs";
  };

  # Firewall rules for Media host (Jellyfin, Sonarr, Radarr, Prowlarr, etc.)
  networking.firewall.interfaces = {
    ens18 = {
      allowedTCPPorts = [ 22 2468 3553 5055 8096 8199 8989 7878 9696 16171 16172 ];
    };
    tailscale0 = {
      allowedTCPPorts = [ 22 2468 3553 5055 8096 8199 16171 16172 ];
    };
  };

  environment.etc."issue".text = lib.mkForce ''

      _____/\\\\\\\\\\\\\\\\\\______________________________________/\\\\\\\\\\__________/\\\\\\\\\\\\\\\\\\\\\\___
      ___/\\\\\\\\\\\\\\\\\\\\\\\\\\__________________________________/\\\\\\///\\\\\\______/\\\\\\/////////\\\\\\_
        __/\\\\\\/////////\\\\\\_______________________________/\\\\\\/__\\///\\\\\\___\\//\\\\\\______\\///__
        _\\/\\\\\\_______\\/\\\\\\__/\\\\/\\\\\\\\\\\\\\___/\\\\/\\\\\\\\\\\\\\___/\\\\\\______\\//\\\\\\___\\////\\\\\\_________
          _\\/\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\_\\/\\\\\\/////\\\\\\_\\/\\\\\\/////\\\\\\_\\/\\\\\\_______\\/\\\\\\______\\////\\\\\\______
          _\\/\\\\\\/////////\\\\\\_\\/\\\\\\___\\///__\\/\\\\\\___\\///__\\//\\\\\\______/\\\\\\__________\\////\\\\\\___
            _\\/\\\\\\_______\\/\\\\\\_\\/\\\\\\_________\\/\\\\\\__________\\///\\\\\\__/\\\\\\_____/\\\\\\______\\//\\\\\\__
            _\\/\\\\\\_______\\/\\\\\\_\\/\\\\\\_________\\/\\\\\\____________\\///\\\\\\\\\\/_____\\///\\\\\\\\\\\\\\\\\\\\\\/___
              _\\///________\\///__\\///__________\\///_______________\\/////_________\///////////_____

                                      Arr • Qbit • VPN • Jellyfin

'';

  # ── Daily Orphan Cleanup — Delete unlinked files in /downloads ────────────────
  # Files with link count = 1 have no hardlink in /media.

  systemd.services.downloads-cleanup = {
    description = "Remove orphaned files (no hardlinks) from /media/HDD1/downloads";
    after       = [ "media-HDD1.mount" ];
    requires    = [ "media-HDD1.mount" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      echo "=== Downloads cleanup started at $(date) ==="

      # Count orphaned files before cleanup
      BEFORE=$(find /media/HDD1/downloads -type f -links 1 | wc -l)
      echo "Orphaned files found: $BEFORE"

      # Delete orphaned files (link count = 1 means no hardlink elsewhere)
      find /media/HDD1/downloads -type f -links 1 -delete -print 2>&1 | head -100

      # Prune empty directories left behind
      find /media/HDD1/downloads -mindepth 1 -type d -empty -delete -print 2>&1 | head -50

      AFTER=$(find /media/HDD1/downloads -type f -links 1 | wc -l)
      echo "Remaining orphaned files: $AFTER"
      echo "=== Downloads cleanup finished at $(date) ==="
    '';
  };

  systemd.timers.downloads-cleanup = {
    wantedBy  = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "*-*-* 03:30:00";
      Persistent         = true;
      RandomizedDelaySec = "10min";
    };
  };
}
