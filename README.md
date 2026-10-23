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

## Email intake

For IMAP intake, set `EMAIL_PROVIDER=imap`, `EMAIL_POLL_ENABLED=true`, and
configure `IMAP_HOST`, `IMAP_PORT`, `IMAP_USER`, `IMAP_PASSWORD`, `IMAP_FOLDER`,
and `IMAP_USE_SSL`. Gmail requires 2-Step Verification and a Google App
Password; use that App Password as `IMAP_PASSWORD` (a regular Gmail password
will not work). Never print mailbox credentials in logs or support output.

Polling is controlled by `EMAIL_POLL_INTERVAL_SECONDS` (300),
`EMAIL_POLL_INITIAL_LOOKBACK_HOURS` (0), and `EMAIL_POLL_MAX_MESSAGES` (25).
`EMAIL_MAX_ATTEMPTS` (5) sets retry attempts and `EMAIL_MAX_ATTACHMENT_MB` (20)
sets the attachment limit. Optional sender controls are `EMAIL_ALLOWED_SENDERS`,
`EMAIL_BLOCKED_SENDERS`, and `EMAIL_SENDER_BLOCKLIST`; `EMAIL_MARK_SEEN` defaults
to false. `EMAIL_BULK_DOMAINS` and `EMAIL_SENDER_ALLOWLIST` configure the
additional sender filters; `EMAIL_ATTACHMENT_MIN_BYTES` (5120) ignores tiny
inline images, and `EMAIL_ATTACHMENT_MAX_BYTES` can set an explicit byte limit.
`EMAIL_BODY_PREVIEW_MAX_CHARS` controls the stored email preview and
`TEST_MAILBOX_ALLOWLIST` restricts test mailbox use. `DOCUMENT_STUCK_TIMEOUT_MINUTES`
(15) sets the stuck-document threshold and `DOCUMENT_STUCK_SWEEP_INTERVAL_SECONDS`
(300) sets the recovery cadence. The admin Dashboard's Email inbox
shows failed and attention-needed mail and supports retry. Celery's `email`
worker handles polling and notifications; the `documents` worker handles
attachment extraction and recovery.
