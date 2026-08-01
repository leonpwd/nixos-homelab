{ pkgs, lib, config, ... }:

{
  # DNS for container-to-container name resolution
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  # Volume directories creation
  systemd.tmpfiles.rules = [
    "d /config/npmplus                   0750 root root -"
    "d /config/npmplus/nginx             0750 root root -"
    "d /config/npmplus/goaccess/geoip   0750 root root -"
    "d /config/npmplus/crowdsec          0750 root root -"
    "d /config/arcane-data               0750 1000 1000 -"
    "d /config/crowdsec/conf             0750 root root -"
    "d /config/crowdsec/conf/acquis.d    0750 root root -"
    "d /config/crowdsec/data             0750 root root -"
    "d /config/npmplus/custom_nginx      0750 root root -"

    # Copy npmplus.yaml from root crowdsec folder to acquis.d
    "C+ /config/crowdsec/conf/acquis.d/npmplus.yaml 0644 root root - ${../../crowdsec/npmplus.yaml}"
  ];
  
  # Auto-registration service for CrowdSec bouncer
  systemd.services."register-crowdsec-bouncer" = {
    description = "Register bouncer API key in CrowdSec";
    after = [ "podman-crowdsec.service" "sops-nix.service" ];
    requires = [ "podman-crowdsec.service" ];
    wantedBy = [ "podman-compose-nginx-root.target" ];
    path = [ pkgs.podman pkgs.gnugrep ];
    script = ''
      API_KEY="$(cat ${config.sops.secrets."crowdsec/bouncer_api_key".path})"

      until podman exec crowdsec cscli bouncers list >/dev/null 2>&1; do
        sleep 2
      done

      if podman exec crowdsec cscli bouncers list -o json | grep -q 'npmplus'; then
        podman exec crowdsec cscli bouncers delete npmplus || true
      fi

      podman exec crowdsec cscli bouncers add npmplus --key "$API_KEY"
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  virtualisation.oci-containers.backend = "podman";

  # ── Containers ─────────────────────────────────────────────────────────────

  virtualisation.oci-containers.containers."arcane" = {
    image = "ghcr.io/getarcaneapp/arcane:latest";
    environment = {
      "DOCKER_HOST" = "tcp://docker-proxy:2375";
      "PGID" = "1000";
      "PUID" = "1000";
      "TZ"   = "Europe/Paris";
    };
    environmentFiles = [ config.sops.templates."arcane.env".path ];
    volumes = [
      "/config/arcane-data:/app/data:rw"
    ];
    ports = [
      "3552:3552/tcp"
    ];
    dependsOn = [
      "docker-proxy"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=arcane"
      "--network=netPROXY"
    ];
  };
  systemd.services."podman-arcane" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-netPROXY.service"
    ];
    requires = [
      "podman-network-netPROXY.service"
    ];
    partOf = [
      "podman-compose-nginx-root.target"
    ];
    upheldBy = [
      "podman-docker-proxy.service"
      "podman-network-netPROXY.service"
    ];
    wantedBy = [
      "podman-compose-nginx-root.target"
    ];
  };

  virtualisation.oci-containers.containers."crowdsec" = {
    image = "docker.io/crowdsecurity/crowdsec:latest";
    environment = {
      "COLLECTIONS" = "ZoeyVid/npmplus";
      "TZ" = "Europe/Paris";
      "USE_WAL" = "true";
    };
    volumes = [
      "/config/crowdsec/conf:/etc/crowdsec:rw"
      "/config/crowdsec/data:/var/lib/crowdsec/data:rw"
      "/config/npmplus/nginx:/opt/npmplus/nginx:ro"
    ];
    ports = [
      "127.0.0.1:7422:7422/tcp"
      "127.0.0.1:8080:8080/tcp"
    ];
    dependsOn = [
      "npmplus"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=crowdsec"
      "--network=netPROXY"
    ];
  };
  systemd.services."podman-crowdsec" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-netPROXY.service"
    ];
    requires = [
      "podman-network-netPROXY.service"
    ];
    partOf = [
      "podman-compose-nginx-root.target"
    ];
    upheldBy = [
      "podman-network-netPROXY.service"
      "podman-npmplus.service"
    ];
    wantedBy = [
      "podman-compose-nginx-root.target"
    ];
  };

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
      "--network=netPROXY"
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
    after = [
      "podman-network-netPROXY.service"
      "podman.service"
    ];
    requires = [
      "podman-network-netPROXY.service"
      "podman.service"
    ];
    partOf = [
      "podman-compose-nginx-root.target"
    ];
    upheldBy = [
      "podman-network-netPROXY.service"
    ];
    wantedBy = [
      "podman-compose-nginx-root.target"
    ];
  };

  virtualisation.oci-containers.containers."npmplus" = {
    image = "docker.io/zoeyvid/npmplus:latest";
    environment = {
      "CLOUDFLARE_REAL_IP" = "true";
      "IPV4_DNS" = "1.1.1.1 8.8.8.8";
      "IPV6_DNS" = "2606:4700:4700::1111 2606:4700:4700::1001";
      "LOGROTATE" = "true";
      "NGINX_LOAD_GEOIP2_MODULE" = "true";
      "TZ"       = "Europe/Paris";
    };
    environmentFiles = [ config.sops.templates."npmplus.env".path ];
    volumes = [
      "/config/npmplus:/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network=host"
    ];
  };
  systemd.services."podman-npmplus" = {
    preStart = ''
      mkdir -p /config/npmplus/crowdsec
      cp -f ${config.sops.templates."npmplus-crowdsec.conf".path} /config/npmplus/crowdsec/crowdsec.conf
      chmod 644 /config/npmplus/crowdsec/crowdsec.conf

      mkdir -p /config/npmplus/custom_nginx
      cp -f ${../../crowdsec/geoip_map.conf} /config/npmplus/custom_nginx/http.conf
      cp -f ${../../crowdsec/geoip_block.conf} /config/npmplus/custom_nginx/server_proxy.conf
      cp -f ${../../crowdsec/geoip_block.conf} /config/npmplus/custom_nginx/location_proxy.conf
      chmod 644 /config/npmplus/custom_nginx/http.conf /config/npmplus/custom_nginx/server_proxy.conf /config/npmplus/custom_nginx/location_proxy.conf
    '';
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [
      "podman-compose-nginx-root.target"
    ];
    wantedBy = [
      "podman-compose-nginx-root.target"
    ];
  };

  virtualisation.oci-containers.containers."npmplus-geoipupdate" = {
    image = "ghcr.io/maxmind/geoipupdate:latest";
    environment = {
      "GEOIPUPDATE_EDITION_IDS" = "GeoLite2-Country GeoLite2-City GeoLite2-ASN";
      "GEOIPUPDATE_FREQUENCY"   = "24";
      "TZ"                      = "Europe/Paris";
    };
    environmentFiles = [ config.sops.templates."geoip.env".path ];
    volumes = [
      "/config/npmplus/goaccess/geoip:/usr/share/GeoIP:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--label=io.containers.autoupdate=registry"
      "--network-alias=geoipupdate"
      "--network=netPROXY"
    ];
  };
  systemd.services."podman-npmplus-geoipupdate" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-netPROXY.service"
    ];
    requires = [
      "podman-network-netPROXY.service"
    ];
    partOf = [
      "podman-compose-nginx-root.target"
    ];
    upheldBy = [
      "podman-network-netPROXY.service"
    ];
    wantedBy = [
      "podman-compose-nginx-root.target"
    ];
  };

  # Networks
  systemd.services."podman-network-netPROXY" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f netPROXY";
    };
    script = ''
      podman network inspect netPROXY || podman network create netPROXY --driver=bridge
    '';
    partOf = [ "podman-compose-nginx-root.target" ];
    wantedBy = [ "podman-compose-nginx-root.target" ];
  };

  # Root service target
  systemd.targets."podman-compose-nginx-root" = {
    unitConfig = {
      Description = "Root target for Proxy containers.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
