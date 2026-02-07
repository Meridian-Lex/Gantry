#!/bin/bash
set -e

# Create lex databases
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE DATABASE lex_state;
    CREATE DATABASE lex_tasks;
    CREATE DATABASE lex_memory;

    \c lex_state
    CREATE EXTENSION IF NOT EXISTS vector;

    \c lex_tasks
    CREATE EXTENSION IF NOT EXISTS vector;

    \c lex_memory
    CREATE EXTENSION IF NOT EXISTS vector;

    -- Create lex user
    CREATE USER lex WITH PASSWORD '${LEX_DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON DATABASE lex_state TO lex;
    GRANT ALL PRIVILEGES ON DATABASE lex_tasks TO lex;
    GRANT ALL PRIVILEGES ON DATABASE lex_memory TO lex;
EOSQL

echo "Lex databases initialized successfully"
