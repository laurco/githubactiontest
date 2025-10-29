name: CI Flask App - Max Notify

on:
  push:
    branches: [ main ]

env:
  REPO: ${{ github.repository }}
  REF: ${{ github.ref }}
  WEBHOOK_URL: https://karri-fruity-wrongfully.ngrok-free.dev/webhook
  NGROK_SECRET: ${{ secrets.DEPLOY_ROBOT_SECRET }}

jobs:
  # === 1. Démarrage + Tests + Notifications (tout en un) ===
  ci:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Python
        run: |
          pip install --upgrade pip

      # === NOTIFY START ===
      - name: Notify Pipeline Start
        run: |
          PAYLOAD=$(jq -n \
            --arg repo "$REPO" \
            --arg ref "$REF" \
            --arg time "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" \
            '{type:"start", repo:$repo, branch:$ref, start_time:$time}')
          SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NGROK_SECRET" | awk '{print $2}')
          echo "Sending START..."
          curl -v \
            -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -H "X-Ngrok-Hmac-Signature: $SIGNATURE" \
            -d "$PAYLOAD" || echo "curl failed"

      # === Step: Setup Python ===
      - name: Notify Step Start - Setup Python
        run: |
          PAYLOAD=$(jq -n \
            --arg repo "$REPO" \
            --arg ref "$REF" \
            --arg step "Setup Python" \
            '{type:"step_start", repo:$repo, branch:$ref, job:"main", step:$step}')
          SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NGROK_SECRET" | awk '{print $2}')
          curl -v -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -H "X-Ngrok-Hmac-Signature: $SIGNATURE" \
            -d "$PAYLOAD" || echo "curl failed"

      # === Install deps ===
      - name: Install Dependencies
        id: install
        continue-on-error: true
        run: |
          pip install -r requirements.txt

      - name: Notify Step End - Install deps
        run: |
          STATUS=$([ "${{ steps.install.outcome }}" = "success" ] && echo "Successful" || echo "Failed")
          PAYLOAD=$(jq -n \
            --arg repo "$REPO" \
            --arg ref "$REF" \
            --arg step "Install deps" \
            --arg status "$STATUS" \
            '{type:"step_end", repo:$repo, branch:$ref, job:"main", step:$step, status_end:$status}')
          SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NGROK_SECRET" | awk '{print $2}')
          curl -v -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -H "X-Ngrok-Hmac-Signature: $SIGNATURE" \
            -d "$PAYLOAD" || echo "curl failed"

      # === Run Tests ===
      - name: Run Tests
        id: tests
        continue-on-error: true
        run: |
          pytest test_app.py -v

      - name: Notify Step End - Run Tests
        run: |
          STATUS=$([ "${{ steps.tests.outcome }}" = "success" ] && echo "Successful" || echo "Failed")
          PAYLOAD=$(jq -n \
            --arg repo "$REPO" \
            --arg ref "$REF" \
            --arg step "Run Tests" \
            --arg status "$STATUS" \
            '{type:"step_end", repo:$repo, branch:$ref, job:"main", step:$step, status_end:$status}')
          SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NGROK_SECRET" | awk '{print $2}')
          curl -v -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -H "X-Ngrok-Hmac-Signature: $SIGNATURE" \
            -d "$PAYLOAD" || echo "curl failed"

      # === Archive & Upload ===
      - name: Archive Results
        if: always()
        run: |
          zip -r results.zip .

      - name: Upload Artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: build-results
          path: results.zip

      # === NOTIFY END (toujours exécuté) ===
      - name: Notify Pipeline End
        if: always()
        run: |
          END_TIME=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
          ARTIFACT_URL="https://github.com/$REPO/actions/runs/$GITHUB_RUN_ID"
          STATUS=$([ "${{ job.status }}" = "success" ] && echo "Successful" || echo "Failed")
          PAYLOAD=$(jq -n \
            --arg repo "$REPO" \
            --arg ref "$REF" \
            --arg time "$END_TIME" \
            --arg url "$ARTIFACT_URL" \
            --arg status "$STATUS" \
            '{type:"end", repo:$repo, branch:$ref, end_time:$time, artifact_url:$url, status:$status}')
          SIGNATURE=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$NGROK_SECRET" | awk '{print $2}')
          echo "Sending END ($STATUS)..."
          curl -v \
            -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -H "X-Ngrok-Hmac-Signature: $SIGNATURE" \
            -d "$PAYLOAD" || echo "curl failed"