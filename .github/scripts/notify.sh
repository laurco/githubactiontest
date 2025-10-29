#!/bin/bash
# notify.sh — Envoie une notification avec HMAC ngrok

set -euo pipefail

TYPE="$1"
STEP="${2:-}"
EXTRA="${3:-"{}"}"

# Construire le payload de base
BASE=$(jq -n \
  --arg repo "$REPO" \
  --arg ref "$REF" \
  --arg job "main" \
  --arg step "$STEP" \
  --arg type "$TYPE" \
  '{
    type: $type,
    repo: $repo,
    branch: $ref,
    job: $job,
    step: $step
  }')

# Fusionner avec EXTRA (si fourni)
if [ "$EXTRA" != "{}" ] && [ -n "$EXTRA" ]; then
  PAYLOAD=$(echo "$BASE" "$EXTRA" | jq -s '.[0] * .[1]')
else
  PAYLOAD="$BASE"
fi

# Calculer HMAC-SHA256
SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NGROK_SECRET" | awk '{print $2}')

# Debug
echo "Sending $TYPE notification..."
echo "URL: $WEBHOOK_URL"
echo "Payload: $PAYLOAD"
echo "HMAC Signature: $SIGNATURE"

# Envoyer
curl -v \
  -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Ngrok-Hmac-Signature: $SIGNATURE" \
  -d "$PAYLOAD" \
  || echo "curl failed (but continuing)"