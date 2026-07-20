#!/usr/bin/env bash
set -euo pipefail

log() { echo "[mtproto-proxy] $(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"; }

log "starting up..."

export GOMAXPROCS="${WORKERS:-1}"

BIND_PORT="${APP_PORT:-443}"
FAKE_DOMAIN="${FAKE_TLS_DOMAIN:-www.cloudflare.com}"
CONFIG_PATH="/app/config.toml"

# ------------------------------------------------------------------
# 1. Resolve the secret.
#    - If SECRET env var is set, use it as-is (recommended for prod:
#      keep it fixed across redeploys, otherwise old client links
#      break every time Railway restarts the container).
#    - If not set, auto-generate a fresh FakeTLS secret on boot and
#      print it clearly to the logs so you can copy it into a
#      Railway Variable to make it permanent.
# ------------------------------------------------------------------
if [ -z "${SECRET:-}" ]; then
  log "no SECRET provided -> generating a random FakeTLS secret for domain '${FAKE_DOMAIN}'"
  SECRET="$(/usr/local/bin/mtg generate-secret --hex "${FAKE_DOMAIN}")"
  log "generated secret: ${SECRET}"
  log "WARNING: this secret is NOT persisted. Set it as a fixed Railway"
  log "         Variable named SECRET to keep the same connect link"
  log "         across restarts/redeploys."
else
  log "using SECRET from environment"
fi

# ------------------------------------------------------------------
# 2. Write mtg's config.toml (mtg v2 only accepts a config file, no
#    raw CLI flags for secret/bind-to).
# ------------------------------------------------------------------
cat > "${CONFIG_PATH}" <<EOF
secret = "${SECRET}"
bind-to = "0.0.0.0:${BIND_PORT}"
EOF

log "config written to ${CONFIG_PATH} (internal bind: 0.0.0.0:${BIND_PORT})"

# ------------------------------------------------------------------
# 3. Build and print the public connect link.
#    SERVER / DISPLAY_PORT should be set to Railway's TCP Proxy
#    domain/port (RAILWAY_TCP_PROXY_DOMAIN / RAILWAY_TCP_PROXY_PORT),
#    since that -- not APP_PORT -- is what clients actually dial.
# ------------------------------------------------------------------
PUBLIC_SERVER="${SERVER:-<set-SERVER-env-to-RAILWAY_TCP_PROXY_DOMAIN>}"
PUBLIC_PORT="${DISPLAY_PORT:-<set-DISPLAY_PORT-env-to-RAILWAY_TCP_PROXY_PORT>}"

log "============================================================"
log " MTProto Proxy connect link:"
log " https://t.me/proxy?server=${PUBLIC_SERVER}&port=${PUBLIC_PORT}&secret=${SECRET}"
log "============================================================"

# ------------------------------------------------------------------
# 4. Run mtg in the foreground (PID 1) so Railway's process
#    supervisor / restart policy and logs work correctly.
# ------------------------------------------------------------------
log "launching mtg..."
exec /usr/local/bin/mtg run "${CONFIG_PATH}"
