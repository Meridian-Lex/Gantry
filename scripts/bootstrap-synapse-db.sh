#!/usr/bin/env bash
# bootstrap-synapse-db.sh — idempotent synapse DB setup on running stratavore-postgres
# Reads POSTGRES_PASSWORD and SYNAPSE_DB_PASSWORD from docker-secrets.env
# Note: migrations are applied by the broker (sqlx) on first startup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../docker-secrets.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found. Run init-docker-secrets.sh first." >&2
  exit 1
fi

# Source only the vars we need (avoid eval of full file)
# POSTGRES_PASSWORD is read to validate the env file is properly initialized,
# even though docker exec uses trust auth (no password required for exec calls)
POSTGRES_PASSWORD=$(grep '^POSTGRES_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)
SYNAPSE_DB_PASSWORD=$(grep '^SYNAPSE_DB_PASSWORD=' "$ENV_FILE" | cut -d= -f2-)

if [[ -z "$POSTGRES_PASSWORD" || -z "$SYNAPSE_DB_PASSWORD" ]]; then
  echo "Error: POSTGRES_PASSWORD or SYNAPSE_DB_PASSWORD missing from $ENV_FILE" >&2
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
