# PetWell Deployment

This project is production-ready through Docker Compose using the base `docker-compose.yml` plus the production override `docker-compose.prod.yml`.

## Recommended Target

Use a VPS with Docker and Docker Compose. Coolify is a good fit because it can deploy a Compose stack and assign a public domain to `nginx`.

Minimum for demo: 4 vCPU, 8 GB RAM, 80 GB SSD.
Recommended for small production: 4-8 vCPU, 16 GB RAM, 100+ GB SSD.

## First-Time Setup

1. Point your domain DNS `A` record to the VPS IP.
2. Copy the template:

```bash
cp .env.production.example .env.production
```

3. Edit `.env.production` and replace every `replace-with-*` value. Generate secrets with:

```bash
openssl rand -hex 32
```

4. Deploy:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

5. Run database migrations after the containers are built:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm user-service pnpm --filter @petwell/user-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm pet-service pnpm --filter @petwell/pet-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm appointment-service pnpm --filter @petwell/appointment-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm ehr-service pnpm --filter @petwell/ehr-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm billing-service pnpm --filter @petwell/billing-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm telemed-service pnpm --filter @petwell/telemed-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm notification-service pnpm --filter @petwell/notification-service prisma:migrate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml run --rm analytics-service pnpm --filter @petwell/analytics-service prisma:migrate:deploy
```

6. Check health:

```bash
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml ps
curl -f https://petwell.example.com/api/health/ready
```

## Network Exposure

The production override closes public ports for Postgres, Redis, RabbitMQ, Mailpit, and MinIO. Only Nginx is public by default. Grafana, Prometheus, and Loki are bound to `127.0.0.1` unless you change the port variables.

## HTTPS

For Coolify, assign the public domain to the `nginx` service and let Coolify manage TLS.

For a raw VPS, put Caddy, Traefik, Nginx Proxy Manager, or another TLS reverse proxy in front of this stack and forward HTTPS traffic to the `nginx` service on port 80.

## Secrets

Never deploy the local `.env`. Use `.env.production`, keep it out of git, and rotate any keys that were shared during development.
