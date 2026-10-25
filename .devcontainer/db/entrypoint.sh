#!/bin/sh
set -e

# Create and seed the database the first time the volume is used.
if [ ! -f "$SQLITE_PATH" ]; then
    echo "Creating SQLite database at $SQLITE_PATH"
    sqlite3 "$SQLITE_PATH" < /docker-entrypoint/init.sql
fi

# Let the non-root user in the app container read and write the file
# (SQLite also needs write access to the folder for its journal file).
chmod 777 "$(dirname "$SQLITE_PATH")"
chmod 666 "$SQLITE_PATH"

# Stay running so the database is available, e.g. via:
#   docker compose exec db sqlite3 /data/app.db
exec sleep infinity
