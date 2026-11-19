#!/usr/bin/env bash
set -euo pipefail
SECRET_ID="${1:-sdm/facturas/config}"
ANON_SALT=$(openssl rand -hex 32)
read -r -p "ISSUER_WHITELIST (separado por comas): " ISSUER_WHITELIST
read -r -p "TEAMS_WEBHOOK_URL: " TEAMS_WEBHOOK_URL

PAYLOAD=$(jq -n --arg s "$ANON_SALT" --arg w "$ISSUER_WHITELIST" --arg t "$TEAMS_WEBHOOK_URL" \
  '{ANON_SALT: $s, ISSUER_WHITELIST: $w, TEAMS_WEBHOOK_URL: $t}')

aws secretsmanager put-secret-value --secret-id "$SECRET_ID" --secret-string "$PAYLOAD" >/dev/null 2>&1 \
  || aws secretsmanager create-secret --name "$SECRET_ID" --secret-string "$PAYLOAD" >/dev/null
echo "Secreto $SECRET_ID actualizado correctamente."
