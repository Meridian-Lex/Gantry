# Network Topology

## Three Named Networks

```
stratavore-frontend    — public-facing services (Traefik, Portainer, Authelia)
stratavore-backend     — internal services (databases, message broker, app services)
stratavore-monitoring  — observability plane (Prometheus, Grafana, Loki, cAdvisor)
```

## Declaration Rules

Networks are **defined once** in `core/docker-compose.yml` and **referenced as external** by all other groups:

```yaml
# core/docker-compose.yml — creates networks
networks:
  frontend-network:
    name: stratavore-frontend
    driver: bridge
  backend-network:
    name: stratavore-backend
    driver: bridge

# storage/docker-compose.yml — references as external
networks:
  backend-network:
    external: true
    name: stratavore-backend
```

- `core/` compose file is always started first — it creates the networks
- All other groups use `external: true` — never re-declare with `driver:`

## Service Placement

| Network | Services |
|---------|---------|
| frontend-network | Traefik, Portainer, Authelia, WebUIs |
| backend-network | PostgreSQL, RabbitMQ, Redis, Qdrant, app services, Synapse |
| monitoring-network | Prometheus, Grafana, Loki, cAdvisor |

- Traefik spans `frontend-network` + `backend-network` (reverse proxy)
- Observability services span `backend-network` + `monitoring-network` (scrape targets)
- Never put databases on `frontend-network`
