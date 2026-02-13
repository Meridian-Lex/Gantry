# Gantry

Docker infrastructure suite for the Stratavore fleet — the support structure from which all vessels are launched and maintained.

## Overview

Gantry provides the complete containerized infrastructure stack for the Meridian Lex autonomous agent system. Services are organized by function with multi-tier network segmentation, automated orchestration, and integrated secrets management.

## Architecture

Services are grouped by function, each with dedicated docker-compose configuration:

**core/** - Infrastructure management
- Portainer (container visibility)
- Traefik (reverse proxy, TLS termination)
- Authelia (authentication + 2FA)

**storage/** - Data persistence
- PostgreSQL 16 + pgvector (agent state database)
- Qdrant (vector memory)
- OpenSearch (log and artifact indexing)
- Memgraph (infrastructure knowledge graph)
- RabbitMQ (message queue coordination)

**observability/** - Monitoring and metrics
- Prometheus (metrics collection)
- Grafana (visualization)
- Loki (log aggregation)
- cAdvisor (container metrics)

**communication/** - Agent integration
- ntfy (bidirectional messaging)
- API Gateway (host-to-container bridge)

**utilities/** - Operational tools
- FileBrowser (filesystem access)
- Watchtower (automated updates)

## Quick Start

```bash
# Initialize secrets (generates credentials from ~/.config/secrets.yaml)
./scripts/init-docker-secrets.sh

# Deploy all service groups
./scripts/deploy-stack.sh
```

## Deployment Sequence

```bash
# Phase 1 - Core infrastructure
docker compose -f core/docker-compose.yml up -d

# Phase 2 - Storage layer
docker compose -f storage/docker-compose.yml up -d

# Phase 3 - Communication
docker compose -f communication/docker-compose.yml up -d

# Phase 4 - Observability
docker compose -f observability/docker-compose.yml up -d

# Phase 5 - Utilities
docker compose -f utilities/docker-compose.yml up -d
```

## Secrets Management

Gantry integrates with the Meridian Lex secrets system (`~/.config/secrets.yaml`) as the single source of truth. Run `scripts/init-docker-secrets.sh` to generate `docker-secrets.env` before first deployment.

Never commit `docker-secrets.env` or `.env` files — they are gitignored.

## Network Topology

Three isolated Docker networks:

- **frontend-network**: Public-facing services (Traefik, Authelia, ntfy, API Gateway)
- **backend-network**: Internal data services (PostgreSQL, Qdrant, OpenSearch, Memgraph, RabbitMQ, Loki)
- **monitoring-network**: Observability stack (Prometheus, Grafana, cAdvisor)

## Integration with Stratavore

Gantry provides the infrastructure layer that Stratavore connects to. The API Gateway bridges the host-based agent to containerized backend services on port 8000.

See `docs/` for full architecture documentation.

---

*Gantry — the launch platform for the Stratavore fleet.*
