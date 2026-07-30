#!/usr/bin/env bash
# Lit le .env local et produit secrets/containers.yaml chiffré (commitable).
# Usage : ./encrypt-secrets.sh  ou  just encrypt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
OUT_FILE="$SCRIPT_DIR/secrets/containers.yaml"

[ -f "$ENV_FILE" ] || { echo "❌ .env introuvable"; exit 1; }

set -a; source "$ENV_FILE"; set +a

mkdir -p "$SCRIPT_DIR/secrets"
touch "$OUT_FILE" && chmod 600 "$OUT_FILE"

cat > "$OUT_FILE" << EOF
arcane:
    encryption_key: "${ARCANE_ENCRYPTION_KEY}"
    jwt_secret: "${ARCANE_JWT_SECRET}"
npmplus:
    acme_email: "${ACME_EMAIL}"
geoip:
    account_id: "${GEOIPUPDATE_ACCOUNT_ID}"
    license_key: "${GEOIPUPDATE_LICENSE_KEY}"
EOF

sops --encrypt --in-place "$OUT_FILE"
chmod 644 "$OUT_FILE"

echo "✅ secrets/containers.yaml chiffré — git add secrets/containers.yaml && git commit"
