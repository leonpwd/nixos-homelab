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
    secrets."hydra/api_key"              = {};
    secrets."hydra/password_hash"        = {};
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
        # Lossless-only automatic downloads; Explo has no sample-rate filter.
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

    # Hydranos default.toml — bind-mounted read-only over /config/default.toml.
    # bind_interface MUST stay empty in [hoard]: in `[network] mode = "gluetun"`,
    # a non-empty bind_interface that isn't the netns' default-route interface
    # makes Hydranos' kill switch BLOCK the engine (silently off the network).
    # [hoard.disk_slots] (per-disk HDD quiet mode) is dead code since 4.4:
    # disk protection instead comes from queueing + active_seeds/active_limit.
    templates."hydra_default.toml" = {
      content = ''
        [daemon]
        agent_token = ""
        api_host = "0.0.0.0"
        api_port = 8199
        api_key = "${config.sops.placeholder."hydra/api_key"}"
        data_dir = "/config"
        create_torrent_folder = false

        [race]
        gluetun_port_forward = false
        gluetun_url = ""
        gluetun_api_key = ""
        webseed_max_concurrent = 48
        enable_webseed = true
        enable_pex = true
        enable_dht = true
        start_paused = false
        max_dials_per_sec = 0.0
        announce_rate_limit = 0.0
        enable_ipv6 = false
        listen_port = 16171
        bind_interface = ""
        listen_interfaces = ""
        max_connections = 4000
        max_uploads_per_torrent = 100
        peer_timeout = 300
        inactivity_timeout = 20

        [race.custom_choking]
        enabled = true
        tick_interval_seconds = 2
        strategy = "rarity_captive"
        max_unchoked = 30
        rarity_weight = 0.7
        speed_weight = 0.3

        [hoard]
        gluetun_port_forward = false
        gluetun_url = ""
        gluetun_api_key = ""
        webseed_max_concurrent = 48
        enable_webseed = true
        enable_pex = true
        enable_dht = true
        start_paused = false
        max_dials_per_sec = 0.0
        announce_rate_limit = 0.0
        enable_ipv6 = false
        listen_port = 16172
        bind_interface = ""
        listen_interfaces = ""
        max_connections = 2000
        max_uploads_per_torrent = -1
        peer_timeout = 300
        inactivity_timeout = 20

        queueing = true
        active_seeds = 40
        active_limit = 50
        active_downloads = 10
        dont_count_slow_torrents = true

        [vpn_speedtest]
        enabled = true
        iperf3_server = "ping.online.net"
        iperf3_port = 5201
        interval_secs = 3600
        duration_secs = 10

        [race_drain]
        reserve_free_gb = 0
        add_block_enabled = true
        age_ratio_action = "delete"
        age_ratio_enabled = false
        age_ratio_mode = "and"
        min_ratio = 0.0
        max_age_hours = 0
        enabled = false
        check_interval_seconds = 60
        high_watermark_pct = 95
        low_watermark_pct = 85
        race_path = "/race"
        min_age_minutes = 10

        [auth]
        username = "lego"
        password_hash = "${config.sops.placeholder."hydra/password_hash"}"

        [announce_muted]
        "gemini-tracker.org" = "1"
        "c411.org" = "1"

        [network]
        mode = "gluetun"
      '';
      uid = 1000;
      gid = 1000;
      mode = "0440";
      restartUnits = [ "podman-hydra.service" ];
    };
  };
}
