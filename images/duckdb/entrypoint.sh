#!/bin/sh
set -e

DB_FILE="${DUCKDB_DATABASE:-/data/university.duckdb}"
INIT_SQL="${DUCKDB_INIT_SQL:-/init/init.sql}"

if [ ! -f "$DB_FILE" ] && [ -f "$INIT_SQL" ]; then
    echo "[duckdb] initializing $DB_FILE from $INIT_SQL"
    duckdb "$DB_FILE" < "$INIT_SQL"
    echo "[duckdb] init done"
else
    echo "[duckdb] using existing $DB_FILE (delete the volume to re-seed)"
fi

exec "$@"
