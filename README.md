# GenWorx AP Assistant

The monorepo contains the services and local infrastructure for the AP Assistant.

## Services

- **AP-Auth** — FastAPI authentication service (host port 8001)
- **AP-Core** — FastAPI invoice, document, PO, vendor, and notification API (host port 8000)
- **AP-Frontend** — React/Vite application served on host port 3000
- **PostgreSQL** — shared database on host port 5433
- **MinIO** — document object storage on ports 9000 (API) and 9001 (console)
- **Redis** — Celery broker on port 6379
- **Worker** — asynchronous AP-Core document processing

## Run locally with Docker Compose

1. Copy `.env.example` to `.env` and replace the placeholder database password and JWT secret. Keep `.env` private.
2. Start the stack with `docker compose up --build`.
3. Set `ADMIN_EMAIL`, `ADMIN_PASSWORD`, and `TEMP_PASSWORD_TTL_HOURS` in `.env`.
4. Apply Auth migrations with `docker compose exec auth alembic upgrade head`.
5. Seed the first admin with `docker compose exec auth python scripts/seed_admin.py`. This skips existing accounts without changing them.
6. Open the frontend at `http://localhost:3000`; API health checks are at `http://localhost:8000/health` and `http://localhost:8001/health`.

The first admin can create associate accounts from the admin-only Associates page. The Dashboard remains available to all authenticated users. Associates sign in with their temporary password, set a new password, and then access the workspace. An expired temporary password requires an admin reset.

Set `ENABLE_GOODS_RECEIPT=true` to register the optional goods-receipt API. API CORS origins are configured by `CORS_ALLOWED_ORIGINS`. For local API development without Compose, follow each service's README and configure its environment from `.env.example`.
