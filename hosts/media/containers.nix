# Media & *Arr Stack Containers — Managed via Podman and SOPS-nix secrets

{ pkgs, lib, config, ... }:

{
  # ── Runtime & DNS ─────────────────────────────────────────────────────────────

  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
    dockerCompat = true;
  };

  # Enable container name DNS for all Podman networks
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  # ── Deterministic Host Directory Creation ─────────────────────────────────────

  systemd.tmpfiles.rules = [
    "d /config/arcane-agent-data         0750 1000 1000 -"
    "d /config/cross-seed                0750 1000 1000 -"
    "d /config/gluetun                   0750 1000 1000 -"
    "d /config/jellyfin                  0750 1000 1000 -"
    "d /config/prowlarr                  0750 1000 1000 -"
    "d /config/qbittorrent               0750 1000 1000 -"
    "d /config/qbittorrent/vuetorrent    0750 1000 1000 -"
    "d /config/qbit_manage               0750 1000 1000 -"
    "d /config/radarr                    0750 1000 1000 -"
    "d /config/seerr                     0750 1000 1000 -"
    "d /config/sonarr                    0750 1000 1000 -"
    "d /media/HDD1                       0775 1000 1000 -"
    "d /media/HDD1/downloads             0775 1000 1000 -"
    "d /media/HDD1/downloads/cross-seed  0775 1000 1000 -"
  ];

  virtualisation.oci-containers.backend = "podman";

  # ── Containers Definitions ───────────────────────────────────────────────────

  # Arcane Agent
  virtualisation.oci-containers.containers."arcane-agent" = {
    image = "ghcr.io/getarcaneapp/agent:latest";
    environment = {
      "AGENT_MODE" = "true";
      "EDGE_TRANSPORT" = "poll";
      "DOCKER_HOST" = "tcp://docker-proxy:2375";
      "TZ" = "Europe/Paris";
    };
    environmentFiles = [ config.sops.templates."arcane.env".path ];
    volumes = [
      "/config/arcane-agent-data:/app/data:rw"
    ];
    ports = [
      "3553:3553/tcp"
    ];
    dependsOn = [
      "docker-proxy"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=arcane-agent"
      "--network=netARR"
    ];
  };
  systemd.services."podman-arcane-agent" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  # Cross-Seed
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

  # Docker Socket Proxy
  virtualisation.oci-containers.containers."docker-proxy" = {
    image = "docker.io/tecnativa/docker-socket-proxy:latest";
    environment = {
      "AUTH" = "0";
      "BUILD" = "0";
      "COMMIT" = "0";
      "CONFIGS" = "0";
      "CONTAINERS" = "1";
      "DISTRIBUTION" = "0";
      "EVENTS" = "1";
      "EXEC" = "1";
      "IMAGES" = "1";
      "INFO" = "1";
      "NETWORKS" = "1";
      "NODES" = "0";
      "PING" = "1";
      "PLUGINS" = "0";
      "POST" = "1";
      "SECRETS" = "0";
      "SERVICES" = "0";
      "SESSION" = "0";
      "SWARM" = "0";
      "SYSTEM" = "0";
      "TASKS" = "0";
      "TZ" = "Europe/Paris";
      "VERSION" = "1";
      "VOLUMES" = "1";
    };
    volumes = [
      "/run/podman/podman.sock:/var/run/docker.sock:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=docker-proxy"
      "--network=netARR"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-docker-proxy" = {
    unitConfig = {
      StartLimitIntervalSec = 0;
    };
    preStart = ''
      if [ -d /run/podman/podman.sock ]; then
        rm -rf /run/podman/podman.sock
      fi
      if [ -d /var/run/docker.sock ]; then
        rm -rf /var/run/docker.sock
      fi
    '';
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" "podman.service" ];
    requires = [ "podman-network-netARR.service" "podman.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  # Gluetun VPN (ProtonVPN)
  virtualisation.oci-containers.containers."gluetun" = {
    image = "ghcr.io/qdm12/gluetun:latest";
    environment = {
      "DNS_UPSTREAM_RESOLVERS" = "cloudflare,quad9 secured,cloudflare security,google";
      "FIREWALL" = "on";
      "FIREWALL_INPUT_PORTS" = "8080,8191,6881,2468";
      "HTTP_CONTROL_SERVER_AUTH_CONFIG_FILEPATH" = "/home/arr/config.toml";
      "HTTP_CONTROL_SERVER_LOG" = "off";
      "PORT_FORWARD_ONLY" = "on";
      "SERVER_COUNTRIES" = "SWITZERLAND,ICELAND,SWEDEN";
      "TZ" = "Europe/Paris";
      "UPDATER_PERIOD" = "24h";
      "VPN_PORT_FORWARDING" = "on";
      "VPN_PORT_FORWARDING_PROVIDER" = "protonvpn";
      "VPN_SERVICE_PROVIDER" = "protonvpn";
      "VPN_TYPE" = "wireguard";
      "WIREGUARD_IMPLEMENTATION" = "kernelspace";
      "WIREGUARD_PRIVATE_KEY_SECRETFILE" = "/run/secrets/wireguard_private_key";
    };
    volumes = [
      "/config/gluetun:/gluetun:rw"
      "${config.sops.templates."gluetun_config.toml".path}:/home/arr/config.toml:ro"
      "${config.sops.templates."wireguard_private_key".path}:/run/secrets/wireguard_private_key:ro"
    ];
    ports = [
      "6881:6881/tcp"
      "6881:6881/udp"
      "8080:8080/tcp"
      "8191:8191/tcp"
      "9696:9696/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--cap-add=NET_ADMIN"
      "--cap-add=NET_RAW"
      "--device=/dev/net/tun:/dev/net/tun:rwm"
      "--network-alias=gluetun"
      "--network=netARR"
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

  # Prowlarr
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
    ];
  };
  systemd.services."podman-prowlarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  # QBittorrent
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
    ];
  };
  systemd.services."podman-qbit" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  # VueTorrent UI Backend
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

  # Radarr
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

  # Sonarr
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

  # Seerr (Jellyseerr)
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

  # qbit_manage — Automated qBittorrent manager
  virtualisation.oci-containers.containers."qbit-manage" = {
    image = "ghcr.io/stuffanthings/qbit_manage:latest";
    environment = {
      "PGID"       = "1000";
      "PUID"       = "1000";
      "QBM_DOCKER" = "true";
      "TZ"         = "Europe/Paris";
    };
    volumes = [
      "/config/qbit_manage:/config:rw"
      "/media/HDD1:/HDD1:rw"
    ];
    dependsOn = [ "gluetun" ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=qbit-manage"
      "--network=netARR"
    ];
  };
  systemd.services."podman-qbit-manage" = {
    preStart = ''
      mkdir -p /config/qbit_manage
      if [ ! -f /config/qbit_manage/config.yml ]; then
        cp -f ${./etc/qbit_manage.config.yml} /config/qbit_manage/config.yml
        chown -R 1000:1000 /config/qbit_manage
        chmod 644 /config/qbit_manage/config.yml
      fi
    '';
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [ "podman-network-netARR.service" ];
    requires = [ "podman-network-netARR.service" ];
    partOf = [ "podman-compose-media-root.target" ];
    wantedBy = [ "podman-compose-media-root.target" ];
  };

  # Networks
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

  # Root service target
  systemd.targets."podman-compose-media-root" = {
    unitConfig = {
      Description = "Root target for Media (*Arr) containers.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
