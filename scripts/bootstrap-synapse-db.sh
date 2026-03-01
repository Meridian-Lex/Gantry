#!/usr/bin/env bash
# bootstrap-synapse-db.sh — idempotent synapse DB setup on running stratavore-postgres
# Reads SYNAPSE_DB_PASSWORD from docker-secrets.env
# Note: migrations are applied by the broker (sqlx) on first startup
# Note: psql runs via `docker exec` which uses peer/trust auth — no password required
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../docker-secrets.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found. Run init-docker-secrets.sh first." >&2
  exit 1
fi

SYNAPSE_DB_PASSWORD=$(grep '^SYNAPSE_DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)

if [[ -z "$SYNAPSE_DB_PASSWORD" ]]; then
  echo "Error: SYNAPSE_DB_PASSWORD missing from $ENV_FILE" >&2
  exit 1
fi

echo "Bootstrapping synapse database on stratavore-postgres..."

docker exec -i stratavore-postgres psql \
  -U postgres \
  -v ON_ERROR_STOP=1 \
  <<SQL
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'synapse') THEN
    CREATE USER synapse WITH PASSWORD '${SYNAPSE_DB_PASSWORD}';
    RAISE NOTICE 'Created user synapse';
  ELSE
    RAISE NOTICE 'User synapse already exists';
  END IF;
END
\$\$;

SELECT 'CREATE DATABASE synapse'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'synapse')\gexec

GRANT ALL PRIVILEGES ON DATABASE synapse TO synapse;
SQL

# Grant schema permissions (required in Postgres 15+; not inherited from DATABASE grant)
docker exec stratavore-postgres psql \
  -U postgres \
  -d synapse \
  -c "GRANT ALL ON SCHEMA public TO synapse;"

echo "Done. Synapse DB ready on stratavore-postgres."
echo "Migrations will be applied by the broker on first startup via sqlx."
