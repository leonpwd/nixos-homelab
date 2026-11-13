{ pkgs, lib, config, ... }:

{
  systemd.tmpfiles.rules = [
    "d /config/npmplus                   0750 root root -"
    "d /config/npmplus/nginx             0750 root root -"
    "d /config/npmplus/goaccess/geoip   0750 root root -"
    "d /config/npmplus/crowdsec          0750 root root -"
    "d /config/crowdsec/conf             0750 root root -"
    "d /config/crowdsec/conf/acquis.d    0750 root root -"
    "d /config/crowdsec/data             0750 root root -"
    "d /config/npmplus/custom_nginx      0750 root root -"

    "d /config/crowdsec/conf/parsers/s02-enrich - - - -"
    "d /config/crowdsec/conf/postoverflows/s01-whitelist - - - -"
  ];
  
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

  virtualisation.oci-containers.containers."crowdsec" = {
    image = "docker.io/crowdsecurity/crowdsec:latest";
    environment = {
      "COLLECTIONS" = "ZoeyVid/npmplus crowdsecurity/http-cve";
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
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-crowdsec" = {
    preStart = ''
      install -D -m 0644 ${../../crowdsec/npmplus.yaml} /config/crowdsec/conf/acquis.d/npmplus.yaml
      install -D -m 0644 ${../../crowdsec/tailscale-whitelist.yaml} /config/crowdsec/conf/parsers/s02-enrich/tailscale-whitelist.yaml
      install -D -m 0644 ${../../crowdsec/tailscale-postoverflow-whitelist.yaml} /config/crowdsec/conf/postoverflows/s01-whitelist/tailscale-whitelist.yaml
      : > /config/crowdsec/conf/acquis.yaml
      for db in GeoLite2-City GeoLite2-ASN; do
        if [ -f /config/npmplus/goaccess/geoip/$db.mmdb ]; then
          install -m 0644 /config/npmplus/goaccess/geoip/$db.mmdb /config/crowdsec/data/$db.mmdb
        fi
      done
    '';
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

  virtualisation.oci-containers.containers."npmplus" = {
    image = "docker.io/zoeyvid/npmplus:latest";
    environment = {
      "TRUST_CLOUDFLARE" = "true";
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
      "--security-opt=no-new-privileges:true"
    ];
  };
  systemd.services."podman-npmplus" = {
    preStart = ''
      mkdir -p /config/npmplus/crowdsec
      cp -f ${config.sops.templates."npmplus-crowdsec.conf".path} /config/npmplus/crowdsec/crowdsec.conf
      chmod 600 /config/npmplus/crowdsec/crowdsec.conf

      mkdir -p /config/npmplus/custom_nginx
      cat ${../../crowdsec/geoip_map.conf} ${./etc/nginx_log_format.conf} > /config/npmplus/custom_nginx/http.conf
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
      "--security-opt=no-new-privileges:true"
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

  systemd.targets."podman-compose-nginx-root" = {
    unitConfig = {
      Description = "Root target for Proxy containers.";
    };
    wantedBy = [ "multi-user.target" ];
  };
}
