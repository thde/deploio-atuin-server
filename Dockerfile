# renovate: datasource=github-releases depName=atuinsh/atuin
ARG ATUIN_VERSION=v18.23.0

FROM cgr.dev/chainguard/rust:latest-dev AS builder

ARG ATUIN_VERSION

# Only the build stage runs as root, to install packages.
# hadolint ignore=DL3002
USER root
RUN apk add --no-cache openssl-dev

WORKDIR /usr/local/src/atuin
RUN git clone --depth 1 --branch "${ATUIN_VERSION}" https://github.com/atuinsh/atuin.git .
RUN cargo build --locked --release --bin atuin-server

FROM cgr.dev/chainguard/wolfi-base:latest
RUN apk add --no-cache libssl3 ca-certificates-bundle

ENV TZ=Etc/UTC
ENV ATUIN_CONFIG_DIR=/tmp/config
ENV RUST_LOG=atuin_server=info

COPY --from=builder /usr/local/src/atuin/target/release/atuin-server /usr/local/bin/atuin-server
COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER 65532

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["start"]
