FROM debian:bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends sqlite3 ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && sqlite3 --version

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /data
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["sleep", "infinity"]
