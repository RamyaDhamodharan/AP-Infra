# Backend E2E check

Run the backend-only check from the repository root in Windows PowerShell 5.1 or
PowerShell 7:

```powershell
.\scripts\run_e2e.ps1
```

The runner starts only the isolated Compose project `ap-backend-e2e`, using
`docker-compose.e2e.yml` over the root Compose definitions and the shared
`ap-core:latest` image. It supplies disposable values from
`scripts/e2e-compose.env`; it does not load the normal developer `.env` file.
The stack has its own project network and data volumes, uses GreenMail instead
of Gmail, and publishes its test APIs and dependencies on the E2E ports. The
normal Compose project and its volumes are left alone.

The runner waits for Auth and Core health endpoints, applies the Auth and Core
Alembic migrations to the isolated database, registers `admin@localhost` and
`associate@localhost`, promotes the test admin in the E2E database, then starts
the checker from the `AP-Core` directory. It invokes:

```powershell
uv run --extra dev python -m scripts.e2e_backend_check
```

Use the AP-Core `uv` environment with the `dev` extra installed; the check needs
`httpx`, `psycopg`, `minio`, `celery`, and test dependencies. Running from
`AP-Core` is required because the checker imports
`tests.e2e.sample_documents`. The script prints one `PASS` or `FAIL` per step
and a final summary. To leave the isolated stack up for inspection:

```powershell
./scripts/run_e2e.ps1 -KeepStack
```

Each run is also appended to `e2e_run.txt` in the repository root. The runner
reports separate build, up, health, migrations, users, and checks phases; Docker
progress written to stderr is captured as ordinary output and only the native
process exit code determines success.

Without `-KeepStack`, cleanup runs only `docker compose -p ap-backend-e2e ...
down --volumes --remove-orphans` for the isolated project.

## Scenarios checked

The checker already covered initial UID checkpointing, email attachment
ingestion with a manually Seen message, classification, match approval, a price
mismatch, duplicate audit, corrupt and text-only email handling, late PO
rematching, supporting-document upload/list/download/delete, invoice timeline
ordering, and poll idempotency. This update also covers the full requested
workflow set:

- PO received by email before its matching invoice email.
- Five-percent price variance and quantity 100 billed against quantity 80 on
  the PO.
- Duplicate invoice, unknown vendor/no PO rejection, and sender notification
  through the outbox.
- Low-confidence invoice verification and an audited associate edit.
- Overdue calculation and all command-center buckets.
- Wrong-GL rejection followed by corrected resubmission.
- Corrupt PDF isolated in a multi-file API upload.
- Vendor issue draft sent through GreenMail and a reply linked back to the
  issue.
- Payment recording with a second payment rejected, plus follow-up creation
  and stop.

The API is used for invoice, issue, draft, supporting-document, command-center,
and follow-up actions. GreenMail SMTP/IMAP drives inbound mail and captures
outbound mail. The checker also reads the isolated Postgres and MinIO test data
to assert internal state and stored objects. All payloads and names are
synthetic.

To stop a kept stack after debugging:

```powershell
docker compose --env-file scripts/e2e-compose.env -p ap-backend-e2e `
  -f docker-compose.yml -f docker-compose.e2e.yml down --volumes --remove-orphans
```
