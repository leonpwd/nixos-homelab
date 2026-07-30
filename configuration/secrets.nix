{ config, ... }:
{
  sops = {
    defaultSopsFile   = ../secrets/containers.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths   = [ "/etc/ssh/ssh_host_ed25519_key" ];

    # ── Secrets ────────────────────────────────────────────────────────────────

    secrets."arcane/encryption_key" = {};
    secrets."arcane/jwt_secret"     = {};
    secrets."npmplus/acme_email"    = {};
    secrets."geoip/account_id"      = {};
    secrets."geoip/license_key"     = {};

    # ── Templates .env injectés dans les containers ────────────────────────────

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
  };
  
  # ── Crowdsec & NPM+ ────────────────────────────────────────────────────────────────
  # Déclaration des secrets issus de SOPS
  sops.secrets."crowdsec/bouncer_api_key" = {};
  sops.secrets."crowdsec/turnstile_secret_key" = {};
  sops.secrets."crowdsec/turnstile_site_key" = {};

  # Template NixOS pour générer /config/npmplus/crowdsec/crowdsec.conf
  sops.templates."npmplus-crowdsec.conf" = {
    content = ''
      ENABLED=true
      API_URL=http://127.0.0.1:8080
      API_KEY=${config.sops.placeholder."crowdsec/bouncer_api_key"}
      CACHE_EXPIRATION=1
      BOUNCING_ON_TYPE=all
      FALLBACK_REMEDIATION=ban
      REQUEST_TIMEOUT=7000
      UPDATE_FREQUENCY=10
      ENABLE_INTERNAL=false
      MODE=stream
      EXCLUDE_LOCATION=
      BAN_TEMPLATE_PATH=/data/crowdsec/ban.html
      REDIRECT_LOCATION=
      RET_CODE=
      CAPTCHA_PROVIDER=turnstile
      SECRET_KEY=${config.sops.placeholder."crowdsec/turnstile_secret_key"}
      SITE_KEY=${config.sops.placeholder."crowdsec/turnstile_site_key"}
      CAPTCHA_TEMPLATE_PATH=/data/crowdsec/captcha.html
      CAPTCHA_EXPIRATION=3600

      APPSEC_URL=http://127.0.0.1:7422
      APPSEC_FAILURE_ACTION=deny
      APPSEC_CONNECT_TIMEOUT=3000
      APPSEC_SEND_TIMEOUT=30000
      APPSEC_PROCESS_TIMEOUT=10000
      ALWAYS_SEND_TO_APPSEC=false
      SSL_VERIFY=true
    '';
    path = "/config/npmplus/crowdsec/crowdsec.conf";
    owner = "root";
    group = "root";
    mode = "0644";
  };
}
