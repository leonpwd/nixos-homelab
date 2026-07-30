{ pkgs, lib, config, ... }:

{
  # DNS pour la résolution des noms de containers entre eux
  networking.firewall.interfaces = let
    matchAll = if !config.networking.nftables.enable then "podman+" else "podman*";
  in {
    "${matchAll}".allowedUDPPorts = [ 53 ];
  };

  # Dossiers de volumes
  systemd.tmpfiles.rules = [
    "d /config/npmplus                   0750 root root -"
    "d /config/npmplus/nginx             0750 root root -"
    "d /config/npmplus/goaccess/geoip   0750 root root -"
    "d /config/npmplus/crowdsec          0750 root root -"
    "d /config/arcane-data               0750 1000 1000 -"
    "d /config/crowdsec/conf             0750 root root -"
    "d /config/crowdsec/conf/acquis.d    0750 root root -"
    "d /config/crowdsec/data             0750 root root -"

    # Génération propre du fichier acquis.d/npmplus.yaml
    "C+ /config/crowdsec/conf/acquis.d/npmplus.yaml 0644 root root - ${pkgs.writeText "npmplus.yaml" ''
      filenames:
        - /config/npmplus/nginx/*.log
      labels:
        type: npmplus
      ---
      listen_addr: 0.0.0.0:7422
      appsec_config: crowdsecurity/appsec-default
      name: appsec
      source: appsec
      labels:
        type: appsec
    ''}"
  ];
  
  # Service d'enregistrement automatique dans le conteneur Crowdsec au boot
  systemd.services."register-crowdsec-bouncer" = {
    description = "Enregistre la clé API bouncer dans Crowdsec";
    after = [ "podman-crowdsec.service" "sops-nix.service" ];
    requires = [ "podman-crowdsec.service" ];
    wantedBy = [ "podman-compose-nginx-root.target" ];
    path = [ pkgs.podman pkgs.gnugrep ];
    script = ''
      API_KEY="${config.sops.placeholder."crowdsec/bouncer_api_key"}"

      until podman exec crowdsec cscli bouncers list >/dev/null 2>&1; do
        sleep 2
      done

      if ! podman exec crowdsec cscli bouncers list -o json | grep -q '"name":"npmplus"'; then
        podman exec crowdsec cscli bouncers add npmplus --key "$API_KEY"
      fi
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  virtualisation.oci-containers.backend = "podman";

  # Containers
  virtualisation.oci-containers.containers."arcane" = {
    image = "ghcr.io/getarcaneapp/arcane:latest";
    environment = {
      "DOCKER_HOST" = "tcp://docker-proxy:2375";
      "PGID" = "1000";
      "PUID" = "1000";
      "TZ"   = "Europe/Paris";
      # ENCRYPTION_KEY et JWT_SECRET → injectés via sops template
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
    image = "tecnativa/docker-socket-proxy:latest";
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
      "/var/run/docker.sock:/var/run/docker.sock:ro"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=docker-proxy"
      "--network=netPROXY"
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-docker-proxy" = {
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
  virtualisation.oci-containers.containers."npmplus" = {
    image = "docker.io/zoeyvid/npmplus:latest";
    environment = {
      "IPV4_DNS" = "1.1.1.1 8.8.8.8";
      "IPV6_DNS" = "2606:4700:4700::1111 2606:4700:4700::1001";
      "LOGROTATE" = "true";
      "NGINX_LOAD_GEOIP2_MODULE" = "true";
      "TZ"       = "Europe/Paris";
      # ACME_EMAIL → injectée via sops template
    };
    environmentFiles = [ config.sops.templates."npmplus.env".path ];
    volumes = [
      "/config/npmplus:/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=host"
    ];
  };
  systemd.services."podman-npmplus" = {
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
      # GEOIPUPDATE_ACCOUNT_ID et GEOIPUPDATE_LICENSE_KEY → injectés via sops template
    };
    environmentFiles = [ config.sops.templates."geoip.env".path ];
    volumes = [
      "/config/npmplus/goaccess/geoip:/usr/share/GeoIP:rw"
    ];
    log-driver = "journald";
    extraOptions = [
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

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."podman-compose-nginx-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
