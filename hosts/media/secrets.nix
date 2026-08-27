{ config, ... }:
{
  sops = {
    defaultSopsFile   = ../../secrets/media.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths   = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # ── Secrets Declarations (Media Host) ──────────────────────────────────────

    secrets."arcane/encryption_key"       = {};
    secrets."arcane/jwt_secret"           = {};
    secrets."arcane/agent_token"          = {};
    secrets."arcane/manager_api_url"      = {};
    secrets."media/wireguard_private_key" = {};
    secrets."media/gsp_api_key"          = {};
    secrets."music/listenbrainz_user"    = {};
    secrets."music/navidrome_username"   = {};
    secrets."music/navidrome_password"   = {};
    secrets."music/slskd_api_key"        = {};
    secrets."music/slskd_web_username"   = {};
    secrets."music/slskd_web_password"   = {};
    secrets."music/soulseek_username"    = {};
    secrets."music/soulseek_password"    = {};

    # ── Secret Files Templates ────────────────────────────────────────────────

    # Arcane Agent Environment File
    templates."arcane.env".content = ''
      AGENT_MODE=true
      EDGE_TRANSPORT=poll
      AGENT_TOKEN=${config.sops.placeholder."arcane/agent_token"}
      MANAGER_API_URL=${config.sops.placeholder."arcane/manager_api_url"}
      ENCRYPTION_KEY=${config.sops.placeholder."arcane/encryption_key"}
      JWT_SECRET=${config.sops.placeholder."arcane/jwt_secret"}
    '';

    # WireGuard Private Key Secret File
    templates."wireguard_private_key" = {
      content = config.sops.placeholder."media/wireguard_private_key";
      mode    = "0400";
    };

    # GSP API Key Secret File
    templates."gsp_api_key" = {
      content = config.sops.placeholder."media/gsp_api_key";
      mode    = "0400";
    };

    # Gluetun config.toml template dynamically embedding GSP_API_KEY
    templates."gluetun_config.toml" = {
      content = ''
        [[roles]]
        name = "t-anc/GSP-Qbittorent-Gluetun-sync-port-mod"
        routes = ["GET /v1/vpn/status", "GET /v1/publicip/ip", "GET /v1/portforward"]
        auth = "apikey"
        apikey = "${config.sops.placeholder."media/gsp_api_key"}"
      '';
      mode = "0644";
    };

    templates."explo.env" = {
      content = ''
        DISCOVERY_SERVICE=listenbrainz
        LISTENBRAINZ_USER=${config.sops.placeholder."music/listenbrainz_user"}
        EXPLO_SYSTEM=subsonic
        SYSTEM_URL=http://navidrome:4533
        SYSTEM_USERNAME=${config.sops.placeholder."music/navidrome_username"}
        SYSTEM_PASSWORD=${config.sops.placeholder."music/navidrome_password"}
        DOWNLOAD_SERVICES=slskd
        SLSKD_URL=http://gluetun:5030
        SLSKD_API_KEY=${config.sops.placeholder."music/slskd_api_key"}
        MIGRATE_DOWNLOADS=false
        USE_SUBDIRECTORY=false
        KEEP_PERMISSIONS=false
        EXTENSIONS=flac,mp3
        LOG_LEVEL=INFO
      '';
      mode = "0400";
    };

    templates."slskd.env" = {
      content = ''
        SLSKD_API_KEY=${config.sops.placeholder."music/slskd_api_key"}
        SLSKD_USERNAME=${config.sops.placeholder."music/slskd_web_username"}
        SLSKD_PASSWORD=${config.sops.placeholder."music/slskd_web_password"}
        SLSKD_SLSK_USERNAME=${config.sops.placeholder."music/soulseek_username"}
        SLSKD_SLSK_PASSWORD=${config.sops.placeholder."music/soulseek_password"}
        SLSKD_VPN_GLUETUN_API_KEY=${config.sops.placeholder."media/gsp_api_key"}
      '';
      mode = "0400";
    };
  };
}
