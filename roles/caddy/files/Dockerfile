# syntax=docker/dockerfile:1.4
# Caddy with Cloudflare DNS module for ACME DNS-01 challenge.
# Use cache mounts to reduce repeated downloads and temp space usage during xcaddy builds.
FROM caddy:builder AS builder
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:latest
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
