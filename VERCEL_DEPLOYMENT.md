# Vercel Deployment

PetWell can use Vercel for the two Next.js frontends:

- `apps/frontend-public-web`
- `apps/frontend-admin-web`

The backend services and databases should not be deployed to Vercel as this repository currently stands. They are long-running services coordinated by Docker Compose: API Gateway, NestJS microservices, Postgres, Redis, RabbitMQ, MinIO, Prometheus, Loki, and Grafana.

## Recommended Architecture

Use Vercel for:

- Public web app
- Admin web app

Use a VPS/Coolify or another container host for:

- `api-gateway`
- all `*-service` backend apps
- Postgres databases
- Redis
- RabbitMQ
- MinIO or S3-compatible storage

This keeps Vercel fast for the UI while preserving functional databases and background services.

## Vercel Projects

Create two Vercel projects from the same Git repository.

### Public Web

Root Directory:

```text
apps/frontend-public-web
```

Environment variable:

```text
NEXT_PUBLIC_API_URL=https://api.your-domain.com
```

If your API is exposed under `/api` on the backend domain, use:

```text
NEXT_PUBLIC_API_URL=https://your-backend-domain.com/api
```

### Admin Web

Root Directory:

```text
apps/frontend-admin-web
```

Environment variable:

```text
NEXT_PUBLIC_API_URL=https://api.your-domain.com
```

or:

```text
NEXT_PUBLIC_API_URL=https://your-backend-domain.com/api
```

## Backend and Database Deployment

For the functional backend and databases, use:

```bash
cp .env.production.example .env.production
corepack pnpm validate:deploy
docker compose --env-file .env.production -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

Then run:

```bash
corepack pnpm deploy:prod:migrate
```

Point Vercel's `NEXT_PUBLIC_API_URL` to the public backend URL.

## Managed Database Alternative

If you do not want databases on the VPS, use managed services:

- Postgres: Neon, Supabase, Prisma Postgres, or another Vercel Marketplace Postgres provider
- Redis: Upstash Redis or another Marketplace Redis provider
- RabbitMQ: CloudAMQP
- Object storage: Cloudflare R2, AWS S3, or another S3-compatible provider

Each backend service still needs its own `DATABASE_URL`, and all services still need somewhere to run outside Vercel unless the backend is rewritten as serverless functions.

## Required Domains

Recommended:

- `https://petwell.com` -> Vercel public web
- `https://admin.petwell.com` -> Vercel admin web
- `https://api.petwell.com` -> backend API Gateway/Nginx

## Important

Rotate any API keys that were present in local `.env` before production.
