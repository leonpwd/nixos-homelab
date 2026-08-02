#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-nginx}"
ENV_FILE="$SCRIPT_DIR/.env.${TARGET}"

if [ ! -f "$ENV_FILE" ]; then
    ENV_FILE="$SCRIPT_DIR/.env"
fi

OUT_FILE="$SCRIPT_DIR/secrets/${TARGET}.yaml"

[ -f "$ENV_FILE" ] || { echo "❌ Fichier d'environnement introuvable (.env.${TARGET} ou .env)"; exit 1; }

set -a; source "$ENV_FILE"; set +a

mkdir -p "$SCRIPT_DIR/secrets"
touch "$OUT_FILE" && chmod 600 "$OUT_FILE"

if [ "$TARGET" = "nginx" ]; then
cat > "$OUT_FILE" << EOF
arcane:
    encryption_key: "${ARCANE_ENCRYPTION_KEY:-}"
    jwt_secret: "${ARCANE_JWT_SECRET:-}"
npmplus:
    acme_email: "${ACME_EMAIL:-}"
geoip:
    account_id: "${GEOIPUPDATE_ACCOUNT_ID:-}"
    license_key: "${GEOIPUPDATE_LICENSE_KEY:-}"
crowdsec:
    bouncer_api_key: "${CROWDSEC_BOUNCER_API_KEY:-}"
    turnstile_secret_key: "${TURNSTILE_SECRET_KEY:-}"
    turnstile_site_key: "${TURNSTILE_SITE_KEY:-}"
EOF
elif [ "$TARGET" = "media" ]; then
cat > "$OUT_FILE" << EOF
arcane:
    encryption_key: "${ARCANE_ENCRYPTION_KEY:-}"
    jwt_secret: "${ARCANE_JWT_SECRET:-}"
    agent_token: "${ARCANE_AGENT_TOKEN:-}"
    manager_api_url: "${ARCANE_MANAGER_API_URL:-http://192.168.1.101:3552}"
media:
    wireguard_private_key: "${WIREGUARD_PRIVATE_KEY:-}"
    gsp_api_key: "${GSP_API_KEY:-}"
EOF
fi

sops --encrypt --in-place "$OUT_FILE"
chmod 644 "$OUT_FILE"

echo "✅ secrets/${TARGET}.yaml chiffré — git add secrets/${TARGET}.yaml && git commit"