# ============================================================
# Telegram MTProto Proxy — Railway-ready Dockerfile
# Engine: 9seconds/mtg (Go implementation of Telegram's
# official MTProto proxy protocol, incl. FakeTLS obfuscation)
# ============================================================

# ---- Stage 1: pull the official, pre-built mtg binary ----
# Pinned to a specific version tag on purpose (never ":latest"),
# so a build here never silently changes behavior later.
FROM ghcr.io/9seconds/mtg:v2.2.4 AS mtg-binary

# ---- Stage 2: minimal runtime image ----
FROM alpine:3.20

# bash      -> our start.sh uses bash features
# openssl   -> used to auto-generate a random secret if none is given
# ca-certificates -> mtg dials out over TLS internally
RUN apk add --no-cache bash openssl ca-certificates tzdata

COPY --from=mtg-binary /mtg /usr/local/bin/mtg
RUN chmod +x /usr/local/bin/mtg

WORKDIR /app
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# ---- Configuration surface (all overridable via Railway Variables) ----
# APP_PORT       internal port the proxy binds to inside the container.
#                This MUST match the "Application Port" you set when you
#                create the Railway TCP Proxy for this service.
# SECRET         MTProto secret (hex). Leave empty to auto-generate on
#                first boot -- but then set it back as a fixed Variable,
#                see README, or it will change on every redeploy.
# FAKE_TLS_DOMAIN domain used to disguise the proxy as normal HTTPS
#                traffic to that domain (FakeTLS / "ee..." secret).
# SERVER         hostname clients will connect to (for generating the
#                t.me/proxy link in logs). Normally set this to
#                ${{RAILWAY_TCP_PROXY_DOMAIN}}.
# DISPLAY_PORT   the externally-visible port (for the link only).
#                Normally set this to ${{RAILWAY_TCP_PROXY_PORT}}.
# WORKERS        maps to GOMAXPROCS, i.e. how many CPU threads the Go
#                runtime is allowed to use concurrently.
ENV APP_PORT=443 \
    SECRET="" \
    FAKE_TLS_DOMAIN=www.cloudflare.com \
    SERVER="" \
    DISPLAY_PORT="" \
    WORKERS=1

EXPOSE 443

ENTRYPOINT ["/app/start.sh"]
