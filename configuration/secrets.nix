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
}
