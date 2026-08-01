{ config, ... }:
{
  sops = {
    defaultSopsFile   = ../../secrets/nginx.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths   = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # ── Secrets Declarations (Nginx Proxy Host) ───────────────────────────────

    secrets."arcane/encryption_key" = {};
    secrets."arcane/jwt_secret"     = {};
    secrets."npmplus/acme_email"    = {};
    secrets."geoip/account_id"      = {};
    secrets."geoip/license_key"     = {};

    # ── CrowdSec / Turnstile Secrets ──────────────────────────────────────────
    secrets."crowdsec/bouncer_api_key" = {};
    secrets."crowdsec/turnstile_secret_key" = {};
    secrets."crowdsec/turnstile_site_key" = {};

    # ── Container .env Templates ───────────────────────────────────────────────

    templates."arcane.env".content = ''
      ENCRYPTION_KEY=${config.sops.placeholder."arcane/encryption_key"}
      JWT_SECRET=${config.sops.placeholder."arcane/jwt_secret"}
    '';

    templates."npmplus.env".content = ''
      ACME_EMAIL=${config.sops.placeholder."npmplus/acme_email"}
    '';

    templates."geoip.env".content = ''
      GEOIPUPDATE_ACCOUNT_ID=${config.sops.placeholder."geoip/account_id"}
      GEOIPUPDATE_LICENSE_KEY=${config.sops.placeholder."geoip/license_key"}
    '';

    # Dynamic template for Nginx CrowdSec bouncer configuration
    templates."npmplus-crowdsec.conf" = {
      content = builtins.replaceStrings
        [ "_BOUNCER_API_KEY_" "_TURNSTILE_SECRET_KEY_" "_TURNSTILE_SITE_KEY_" ]
        [
          config.sops.placeholder."crowdsec/bouncer_api_key"
          config.sops.placeholder."crowdsec/turnstile_secret_key"
          config.sops.placeholder."crowdsec/turnstile_site_key"
        ]
        (builtins.readFile ../../crowdsec/npmplus-crowdsec.conf);
      owner = "root";
      group = "root";
      mode  = "0644";
    };
  };
}
