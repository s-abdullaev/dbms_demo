#!/bin/sh
set -e

DB_FILE="${SQLITE_DATABASE:-/data/university.sqlite}"
INIT_SQL="${SQLITE_INIT_SQL:-/init/init.sql}"

if [ ! -f "$DB_FILE" ] && [ -f "$INIT_SQL" ]; then
    echo "[sqlite] initializing $DB_FILE from $INIT_SQL"
    sqlite3 "$DB_FILE" < "$INIT_SQL"
    echo "[sqlite] init done"
else
    echo "[sqlite] using existing $DB_FILE (delete the volume to re-seed)"
fi

exec "$@"
