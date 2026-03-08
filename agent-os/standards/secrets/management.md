# Secrets Management

## Source of Truth

All secrets stored in `~/.config/secrets.yaml` under `docker_services.*` — never hardcoded or committed.

## Workflow

```bash
# 1. Generate/sync secrets from secrets.yaml to docker-secrets.env
scripts/init-docker-secrets.sh

# 2. Inspect generated env file (verify, never commit)
cat docker-secrets.env

# 3. Deploy — compose picks up env_file automatically
docker compose -f storage/docker-compose.yml up -d
```

## init-docker-secrets.sh Pattern

```bash
get_secret() { yq eval ".docker_services.$key" ~/.config/secrets.yaml; }
set_secret() { yq eval -i ".docker_services.$key = \"$value\"" ~/.config/secrets.yaml; }

# Idempotent: read existing, generate only if null
if [[ "$(get_secret postgres.password)" == "null" ]]; then
    set_secret postgres.password "$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32)"
fi
```

- `openssl rand -base64 32 | tr -d "=+/" | cut -c1-32` — standard password generation
- Always idempotent — re-running does not rotate existing secrets
- Uses `yq` (required dependency) for YAML reads/writes

## docker-secrets.env

- Generated file — `chmod 600` enforced by init script
- `.gitignore` must exclude it — never committed
- `.env.example` template committed in its place
- All secrets consumed via `env_file: - ../docker-secrets.env` in compose files
