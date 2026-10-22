$ErrorActionPreference = "Stop"
$ProjectName = "ap-backend-e2e"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$coreRoot = Join-Path $repoRoot "AP-Core"
$composeBase = Join-Path $repoRoot "docker-compose.yml"
$composeOverride = Join-Path $repoRoot "docker-compose.e2e.yml"
$composeEnv = Join-Path ([System.IO.Path]::GetTempPath()) "ap-backend-e2e-$PID.env"
$stackStarted = $false

function Invoke-Compose {
    param([string[]]$Arguments)
    & docker compose --project-name $ProjectName --env-file $composeEnv `
        --file $composeBase --file $composeOverride @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed with exit code $LASTEXITCODE"
    }
}

try {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw "Docker CLI was not found. Install Docker Desktop and retry."
    }

    @(
        "POSTGRES_USER=ap_e2e_user",
        "POSTGRES_PASSWORD=e2e-only-postgres-password",
        "POSTGRES_DB=genworx_ap_e2e",
        "JWT_SECRET_KEY=e2e-only-jwt-signing-key-change-me",
        "MINIO_ROOT_USER=e2e-minio-user",
        "MINIO_ROOT_PASSWORD=e2e-only-minio-password",
        "OPENROUTER_API_KEY=",
        "OPENROUTER_MODEL=",
        "GROQ_API_KEY=",
        "GROQ_MODEL=",
        "GROQ_FALLBACK_MODEL=",
        "REDIS_URL=redis://redis:6379/0",
        "IMAP_HOST=greenmail",
        "IMAP_PORT=3143",
        "IMAP_USER=ap-test@localhost",
        "IMAP_PASSWORD=test-only-password",
        "IMAP_USE_SSL=false",
        "EMAIL_POLL_ENABLED=true",
        "EMAIL_POLL_INTERVAL_SECONDS=30"
    ) | Set-Content -LiteralPath $composeEnv -Encoding ascii

    Write-Host "Starting isolated Compose project '$ProjectName'..."
    $stackStarted = $true
    Invoke-Compose @("up", "--detach", "--build")

    $healthy = $false
    for ($attempt = 0; $attempt -lt 120; $attempt++) {
        try {
            $core = Invoke-RestMethod -Uri "http://127.0.0.1:18000/health" -TimeoutSec 2
            $auth = Invoke-RestMethod -Uri "http://127.0.0.1:18001/health" -TimeoutSec 2
            if ($core.status -eq "ok" -and $auth.status -eq "ok") {
                $healthy = $true
                break
            }
        }
        catch {
            Start-Sleep -Seconds 1
        }
    }
    if (-not $healthy) {
        throw "Core/Auth health checks did not become ready within 120 seconds."
    }

    Write-Host "Applying Auth and Core migrations..."
    Invoke-Compose @("exec", "--no-TTY", "auth", "alembic", "upgrade", "head")
    Invoke-Compose @("exec", "--no-TTY", "core", "uv", "run", "--no-sync", "alembic", "upgrade", "head")

    Write-Host "Creating isolated E2E administrator..."
    $adminPasswordInput = "e2e-local-user-password-only`ne2e-local-user-password-only`n"
    $adminPasswordInput | & docker compose --project-name $ProjectName --env-file $composeEnv `
        --file $composeBase --file $composeOverride exec --no-TTY auth `
        python scripts/create_admin.py --email admin@localhost
    if ($LASTEXITCODE -ne 0) {
        throw "E2E admin seeding failed with exit code $LASTEXITCODE"
    }

    Write-Host "Running backend E2E checks..."
    Push-Location $coreRoot
    try {
        uv run --extra dev python -m scripts.e2e_backend_check
        if ($LASTEXITCODE -ne 0) {
            throw "Backend E2E checks failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if ($stackStarted) {
        Write-Host "Tearing down only Compose project '$ProjectName' and its volumes..."
        & docker compose --project-name $ProjectName --env-file $composeEnv `
            --file $composeBase --file $composeOverride down --volumes --remove-orphans
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Isolated E2E Compose teardown failed with exit code $LASTEXITCODE"
        }
    }
    if (Test-Path -LiteralPath $composeEnv) {
        Remove-Item -LiteralPath $composeEnv -Force
    }
}
