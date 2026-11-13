{ config, pkgs, inputs, ... }:
{
  sops = {
    package           = inputs.sops-nix.packages.${pkgs.stdenv.hostPlatform.system}.sops-install-secrets;
    defaultSopsFile   = ../../secrets/media.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths   = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # ── Secrets Declarations (Media Host) ──────────────────────────────────────

    secrets."media/wireguard_private_key" = {};
    secrets."media/gsp_api_key"          = {};
    secrets."music/listenbrainz_user"    = {};
    secrets."music/listenbrainz_user_token" = {};
    secrets."music/navidrome_username"   = {};
    secrets."music/navidrome_password"   = {};
    secrets."music/slskd_api_key"        = {};
    secrets."music/slskd_web_username"   = {};
    secrets."music/slskd_web_password"   = {};
    secrets."music/soulseek_username"    = {};
    secrets."music/soulseek_password"    = {};

    # ── Secret Files Templates ────────────────────────────────────────────────

    templates."wireguard_private_key" = {
      content = config.sops.placeholder."media/wireguard_private_key";
      mode    = "0400";
    };

    templates."gsp_api_key" = {
      content = config.sops.placeholder."media/gsp_api_key";
      mode    = "0400";
    };

    templates."gluetun_config.toml" = {
      content = ''
        [[roles]]
        name = "t-anc/GSP-Qbittorent-Gluetun-sync-port-mod"
        routes = ["GET /v1/vpn/status", "GET /v1/publicip/ip", "GET /v1/portforward"]
        auth = "apikey"
        apikey = "${config.sops.placeholder."media/gsp_api_key"}"
      '';
      mode = "0400";
    };

    templates."explo.env" = {
      content = ''
        DISCOVERY_SERVICE=listenbrainz
        LISTENBRAINZ_USER=${config.sops.placeholder."music/listenbrainz_user"}
        LISTENBRAINZ_USER_TOKEN=${config.sops.placeholder."music/listenbrainz_user_token"}
        EXPLO_SYSTEM=subsonic
        SYSTEM_URL=http://navidrome:4533
        SYSTEM_USERNAME=${config.sops.placeholder."music/navidrome_username"}
        SYSTEM_PASSWORD=${config.sops.placeholder."music/navidrome_password"}
        DOWNLOAD_SERVICES=slskd
        SLSKD_URL=http://gluetun:5030
        SLSKD_API_KEY=${config.sops.placeholder."music/slskd_api_key"}
        UI_USERNAME=${config.sops.placeholder."music/slskd_web_username"}
        UI_PASSWORD=${config.sops.placeholder."music/slskd_web_password"}
        MIGRATE_DOWNLOADS=false
        SLSKD_MIGRATE_DOWNLOADS=false
        SLSKD_OVERWRITE_METADATA=false
        USE_SUBDIRECTORY=false
        SLSKD_KEEP_PERMISSIONS=false
        EXTENSIONS=flac
        MIN_BIT_DEPTH=16
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
