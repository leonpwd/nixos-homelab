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
        routes = ["GET /v1/portforward"]
        auth = "apikey"
        apikey = "${config.sops.placeholder."media/gsp_api_key"}"
      '';
      mode = "0644";
    };
  };
}
