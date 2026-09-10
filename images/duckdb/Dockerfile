FROM debian:bookworm-slim

ARG DUCKDB_VERSION=1.1.3
ARG TARGETARCH=amd64

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && case "${TARGETARCH}" in \
      amd64) DUCKDB_ARCH=amd64 ;; \
      arm64) DUCKDB_ARCH=aarch64 ;; \
      *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
 && curl -fsSL -o /tmp/duckdb.zip \
      "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/duckdb_cli-linux-${DUCKDB_ARCH}.zip" \
 && unzip /tmp/duckdb.zip -d /usr/local/bin \
 && chmod +x /usr/local/bin/duckdb \
 && rm /tmp/duckdb.zip \
 && duckdb -c "SELECT 'duckdb ' || version() AS installed;"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /data
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
