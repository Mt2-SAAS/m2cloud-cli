# M2 Cloud agent container image (packaging/README.md, ADR-009).
#
# Build from the repository root, the module lives at apps/m2-cli:
#   docker build -f packaging/docker/Dockerfile -t m2cloud-agent:test .
#
# Multi-stage: the build stage compiles the single Go binary from source
# (CGO_ENABLED=0, -trimpath, same flags as scripts/build-cli.sh); the runtime
# stage ships nothing but that static binary, CA certificates and a non-root
# user.

# ── Build ─────────────────────────────────────────────────────────────────
FROM golang:1.27-alpine AS build

ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_DATE=unknown

WORKDIR /src
COPY apps/m2-cli/go.mod apps/m2-cli/go.sum ./
RUN go mod download
COPY apps/m2-cli/ .

RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w \
        -X github.com/Mt2-SAAS/m2cloud/apps/m2-cli/internal/cli.Version=${VERSION} \
        -X github.com/Mt2-SAAS/m2cloud/apps/m2-cli/internal/cli.Commit=${COMMIT} \
        -X github.com/Mt2-SAAS/m2cloud/apps/m2-cli/internal/cli.BuildDate=${BUILD_DATE}" \
      -o /out/m2cloud ./cmd/m2cloud

# State directory (identity.json, identity.key at 0600) owned by the
# non-root user the runtime stage runs as (distroless "nonroot", uid 65532),
# created here because the runtime stage has no shell to chown it with.
RUN mkdir -p /state && chown 65532:65532 /state

# ── Runtime ───────────────────────────────────────────────────────────────
FROM gcr.io/distroless/static-debian12:nonroot

COPY --from=build /out/m2cloud /usr/local/bin/m2cloud
COPY --from=build --chown=65532:65532 /state /var/lib/m2cloud

# /var/lib/m2cloud holds the installation identity (ADR-009, ADR-004) and
# must survive container recreation: mount a named volume or bind mount over
# it. The agent configuration (agent.toml) is not baked into the image
# either — mount it read-only, e.g. `-v ./agent.toml:/etc/m2cloud/agent.toml:ro`.
VOLUME ["/var/lib/m2cloud"]
WORKDIR /var/lib/m2cloud

USER nonroot:nonroot

# `m2cloud run` never daemonizes (ADR-009): it is the container's foreground
# process and Docker/the orchestrator supervises restarts. The entrypoint is
# the binary itself, not "run", so `docker run --rm --entrypoint
# /usr/local/bin/m2cloud <image> version` (or `config validate`, `doctor`)
# works without overriding the whole array (see packaging/README.md).
ENTRYPOINT ["/usr/local/bin/m2cloud", "run"]
CMD ["--config", "/etc/m2cloud/agent.toml"]
STOPSIGNAL SIGTERM
