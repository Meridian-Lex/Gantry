#!/bin/bash
set -e

# Create lex databases
psql -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$POSTGRES_DB" \
    --set=lex_db_password="$LEX_DB_PASSWORD" \
    --set=synapse_db_password="$SYNAPSE_DB_PASSWORD" \
    --set=stratavore_db_password="$STRATAVORE_DB_PASSWORD" <<-EOSQL
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
    CREATE USER lex WITH PASSWORD :'lex_db_password';
    GRANT ALL PRIVILEGES ON DATABASE lex_state TO lex;
    GRANT ALL PRIVILEGES ON DATABASE lex_tasks TO lex;
    GRANT ALL PRIVILEGES ON DATABASE lex_memory TO lex;

    -- Synapse broker database
    CREATE DATABASE synapse;
    CREATE USER synapse WITH PASSWORD :'synapse_db_password';
    GRANT ALL PRIVILEGES ON DATABASE synapse TO synapse;
    \c synapse
    GRANT ALL ON SCHEMA public TO synapse;

    -- Stratavore orchestration database
    CREATE DATABASE stratavore_state;
    CREATE USER stratavore WITH PASSWORD :'stratavore_db_password';
    GRANT ALL PRIVILEGES ON DATABASE stratavore_state TO stratavore;
    \c stratavore_state
    CREATE EXTENSION IF NOT EXISTS vector;
    GRANT ALL ON SCHEMA public TO stratavore;
EOSQL

echo "Lex databases initialized successfully"
