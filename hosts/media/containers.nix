
{ pkgs, lib, config, ... }:

{
  # ── Deterministic Host Directory Creation ─────────────────────────────────────

  systemd.tmpfiles.rules = [
    "d /config/cross-seed                0750 1000 1000 -"
    "d /config/gluetun                   0750 1000 1000 -"
    "d /config/hydra-qbit                0750 1000 1000 -"
    "d /config/jellyfin                  0750 1000 1000 -"
    "d /config/prowlarr                  0750 1000 1000 -"
    "d /config/qbittorrent               0750 1000 1000 -"
    "d /config/qbittorrent/vuetorrent    0750 1000 1000 -"
    "d /config/radarr                    0750 1000 1000 -"
    "d /config/seerr                     0750 1000 1000 -"
    "d /config/sonarr                    0750 1000 1000 -"
    "d /config/navidrome                 0750 1000 1000 -"
    "d /config/explo                     0750 1000 1000 -"
    "d /config/slskd                     0750 1000 1000 -"
    "d /config/beets                     0750 1000 1000 -"
    "d /media/HDD1                       0775 1000 1000 -"
    "d /media/HDD1/downloads             0775 1000 1000 -"
    "d /media/HDD1/downloads/cross-seed  0775 1000 1000 -"
    "d /media/HDD1/media                 2775 1000 1000 -"
    "d /media/HDD1/media/Music           0775 1000 1000 -"
    "d /media/HDD1/media/Music/Inbox     0775 1000 1000 -"
    "d /media/HDD1/media/Music/Inbox/complete   0775 1000 1000 -"
    "d /media/HDD1/media/Music/Inbox/incomplete 0775 1000 1000 -"
    "f /media/HDD1/media/Music/Inbox/incomplete/.ndignore 0644 1000 1000 -"
  ];

  virtualisation.oci-containers.backend = "podman";

  # ── Containers Definitions ───────────────────────────────────────────────────

  virtualisation.oci-containers.containers."cross-seed" = {
    image = "ghcr.io/cross-seed/cross-seed:latest";
    environment = {
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/cross-seed:/config:rw"
      "/media/HDD1:/HDD1:rw"
    ];
    cmd = [ "daemon" ];
    ports = [
      "2468:2468/tcp"
    ];
    dependsOn = [ "gluetun" ];
    user = "1000:1000";
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=cross-seed"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-cross-seed" = {
    preStart = ''
      mkdir -p /config/cross-seed
      if [ ! -f /config/cross-seed/config.js ]; then
        cp -f ${./etc/cross-seed.config.js} /config/cross-seed/config.js
        chown -R 1000:1000 /config/cross-seed
        chmod 644 /config/cross-seed/config.js
      fi
    '';
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."gluetun" = {
    image = "ghcr.io/qdm12/gluetun:latest";
    environment = {
      "DNS_UPSTREAM_RESOLVERS" = "cloudflare,cloudflare security,google";
      "FIREWALL" = "on";
      "FIREWALL_INPUT_PORTS" = "5030,8080,8191,6881,2468,8199,16171,16172";
      "FIREWALL_VPN_INPUT_PORTS" = "16171,16172";
      "HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH" = "/home/arr/config.toml";
      "HTTP_CONTROL_SERVER_LOG" = "off";
      "PORT_FORWARD_ONLY" = "on";
      "SERVER_COUNTRIES" = "SWITZERLAND,ICELAND,SWEDEN";
      "TZ" = "Europe/Paris";
      "UPDATER_PERIOD" = "24h";
      "VPN_PORT_FORWARDING" = "on";
      "VPN_PORT_FORWARDING_PROVIDER" = "protonvpn";
      "VPN_PORT_FORWARDING_UP_COMMAND" = "/bin/sh -c 'wget -qO- --header=\"Content-Type: application/json\" --post-data=\"{\\\"port\\\":{{PORT}}}\" http://127.0.0.1:8199/api/hoard/listen-port || true'";
      "VPN_SERVICE_PROVIDER" = "protonvpn";
      "VPN_TYPE" = "wireguard";
      "WIREGUARD_MTU" = "1320";
      "WIREGUARD_IMPLEMENTATION" = "kernelspace";
      "WIREGUARD_PRIVATE_KEY_SECRETFILE" = "/run/secrets/wireguard_private_key";
    };
    volumes = [
      "/config/gluetun:/gluetun:rw"
      "${config.sops.templates."gluetun_config.toml".path}:/home/arr/config.toml:ro"
      "${config.sops.templates."wireguard_private_key".path}:/run/secrets/wireguard_private_key:ro"
    ];
    ports = [
      "8080:8080/tcp"
      "8199:8199/tcp"
      "9696:9696/tcp"
      "16171:16171/tcp"
      "16171:16171/udp"
      "16172:16172/tcp"
      "16172:16172/udp"
      "5030:5030/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      "--device=/dev/net/tun:/dev/net/tun:rwm"
      "--network-alias=gluetun"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-gluetun" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."slskd" = {
    image = "docker.io/slskd/slskd:latest";
    environment = {
      "SLSKD_REMOTE_CONFIGURATION" = "true";
      "SLSKD_REMOTE_FILE_MANAGEMENT" = "true";
      "SLSKD_DOWNLOADS_DIR" = "/downloads/complete";
      "SLSKD_INCOMPLETE_DIR" = "/downloads/incomplete";
      "SLSKD_SHARED_DIR" = "/music";
      "SLSKD_SLSK_LISTEN_PORT" = "50300";
      "SLSKD_UMASK" = "002";
      "SLSKD_VPN" = "false";
      "SLSKD_VPN_PORT_FORWARDING" = "false";
      "SLSKD_VPN_GLUETUN_URL" = "http://127.0.0.1:8000";
      "TZ" = "Europe/Paris";
    };
    environmentFiles = [ config.sops.templates."slskd.env".path ];
    volumes = [
      "/config/slskd:/app:rw"
      "/media/HDD1/media/Music/Inbox:/downloads:rw"
      "/media/HDD1/media/Music:/music:ro"
    ];
    dependsOn = [ "gluetun" ];
    user = "1000:1000";
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network=container:gluetun"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-slskd" = {
    serviceConfig.Restart = lib.mkOverride 90 "always";
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
    bindsTo = [ "podman-gluetun.service" ];
  };

  virtualisation.oci-containers.containers."navidrome" = {
    image = "docker.io/deluan/navidrome:latest";
    environment = {
      "ND_LOGLEVEL" = "info";
      "ND_SCANSCHEDULE" = "1m";
      "ND_SESSIONTIMEOUT" = "24h";
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/navidrome:/data:rw"
      "/media/HDD1/media/Music:/music:ro"
    ];
    ports = [ "4533:4533/tcp" ];
    user = "1000:1000";
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=navidrome"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-navidrome" = {
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."explo" = {
    image = "ghcr.io/lumepart/explo:latest";
    volumes = [
      "/config/explo/.env:/opt/explo/.env:rw"
      "/config/explo:/opt/explo/config:rw"
      "/media/HDD1/media/Music:/data:ro"
      "/media/HDD1/media/Music/Inbox/complete:/slskd:ro"
    ];
    ports = [ "7288:7288/tcp" ];
    dependsOn = [ "navidrome" "slskd" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=explo"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-explo" = {
    preStart = ''
      install -d -m 0750 -o 1000 -g 1000 /config/explo
      if [ ! -s /config/explo/.env ]; then
        install -m 0600 ${config.sops.templates."explo.env".path} /config/explo/.env
      fi
    '';
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."beets" = {
    image = "lscr.io/linuxserver/beets:latest";
    environment = {
      "PUID" = "1000";
      "PGID" = "1000";
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/beets:/config:rw"
      "/media/HDD1/media/Music:/music:rw"
      "${./etc/beets.config.yaml}:/config/config.yaml:ro"
    ];
    ports = [ "8337:8337/tcp" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=beets"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-beets" = {
    serviceConfig.Restart = lib.mkOverride 90 "always";
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  systemd.services."beets-import" = {
    description = "Tag and organize new Soulseek music with Beets";
    after = [ "podman-beets.service" ];
    requires = [ "podman-beets.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.podman}/bin/podman exec --user 1000:1000 beets beet -c /config/config.yaml import -q /music/Inbox/complete";
    };
  };

  systemd.timers."beets-import" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitInactiveSec = "5min";
      Persistent = true;
    };
  };

  virtualisation.oci-containers.containers."prowlarr" = {
    image = "lscr.io/linuxserver/prowlarr:latest";
    environment = {
      "PGID" = "1000";
      "PUID" = "1000";
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/prowlarr:/config:rw"
    ];
    dependsOn = [ "gluetun" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network=container:gluetun"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-prowlarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
    bindsTo = [ "podman-gluetun.service" ];
  };

  virtualisation.oci-containers.containers."qbit" = {
    image = "lscr.io/linuxserver/qbittorrent:latest";
    environment = {
      "DOCKER_MODS" = "ghcr.io/t-anc/gsp-qbittorent-gluetun-sync-port-mod:main";
      "GSP_GTN_API_KEY_FILE" = "/run/secrets/gsp_api_key";
      "PGID" = "1000";
      "PUID" = "1000";
      "TZ" = "Europe/Paris";
      "WEBUI_PORT" = "8080";
    };
    volumes = [
      "/config/qbittorrent:/config:rw"
      "${config.sops.templates."gsp_api_key".path}:/run/secrets/gsp_api_key:ro"
      "/media/HDD1/downloads:/HDD1/downloads:rw"
    ];
    dependsOn = [ "gluetun" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network=container:gluetun"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-qbit" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
    bindsTo = [ "podman-gluetun.service" ];
  };

  virtualisation.oci-containers.containers."qbit-ui-backend" = {
    image = "ghcr.io/vuetorrent/vuetorrent-backend:latest";
    environment = {
      "CONFIG_PATH" = "/config";
      "PORT" = "8081";
      "QBIT_BASE" = "http://gluetun:8080";
      "RELEASE_TYPE" = "stable";
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/qbittorrent/vuetorrent:/config:rw"
    ];
    ports = [
      "8081:8081/tcp"
    ];
    dependsOn = [ "qbit" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--dns=1.1.1.1"
      "--dns=8.8.8.8"
      "--network-alias=vuetorrent-backend"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-qbit-ui-backend" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."radarr" = {
    image = "lscr.io/linuxserver/radarr:latest";
    environment = {
      "PGID" = "1000";
      "PUID" = "1000";
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/radarr:/config:rw"
      "/media/HDD1:/HDD1:rw"
    ];
    ports = [
      "7878:7878/tcp"
    ];
    dependsOn = [ "qbit" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=radarr"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-radarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."sonarr" = {
    image = "lscr.io/linuxserver/sonarr:latest";
    environment = {
      "PGID" = "1000";
      "PUID" = "1000";
      "TZ" = "Europe/Paris";
    };
    volumes = [
      "/config/sonarr:/config:rw"
      "/media/HDD1:/HDD1:rw"
    ];
    ports = [
      "8989:8989/tcp"
    ];
    dependsOn = [ "qbit" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=sonarr"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-sonarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."seerr" = {
    image = "ghcr.io/seerr-team/seerr:latest";
    environment = {
      "LOG_LEVEL" = "info";
      "TZ"        = "Europe/Paris";
    };
    volumes = [
      "/config/seerr:/app/config:rw"
    ];
    ports = [
      "5055:5055/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=seerr"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-seerr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  virtualisation.oci-containers.containers."hydra" = {
    image = "ghcr.io/kheopsian/hydranos:latest";
    environment = {
      "TZ" = "Europe/Paris";
      "PUID" = "1000";
      "PGID" = "1000";
    };
    volumes = [
      "/config/hydra-qbit:/config:rw"
      "/media/HDD1:/HDD1:rw"
    ];
    dependsOn = [ "gluetun" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network=container:gluetun"
      "--stop-timeout=150"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-hydra" = {
    preStart = ''
      mkdir -p /config/hydra-qbit
      if [ ! -f /config/hydra-qbit/default.toml ]; then
        cp -f ${./etc/hydra-default.toml} /config/hydra-qbit/default.toml
        chown 1000:1000 /config/hydra-qbit/default.toml
        chmod 600 /config/hydra-qbit/default.toml
      fi
    '';
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      TimeoutStopSec = lib.mkOverride 90 170;
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
    bindsTo = [ "podman-gluetun.service" ];
  };


  systemd.services."podman-network-netARR" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f netARR";
    };
    script = ''
      podman network inspect netARR || podman network create netARR --driver=bridge
    '';
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  systemd.targets."podman-compose-media-root" = {
    unitConfig = {
      Description = "Root target for Media (*Arr) containers.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
