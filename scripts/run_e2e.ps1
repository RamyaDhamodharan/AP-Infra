[CmdletBinding()]
param(
    [switch]$KeepStack
)

$ErrorActionPreference = 'Stop'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Core = Join-Path $Root 'AP-Core'
$ComposeEnv = Join-Path $PSScriptRoot 'e2e-compose.env'
$Project = 'ap-backend-e2e'
$ComposeFiles = @('-f', (Join-Path $Root 'docker-compose.yml'), '-f', (Join-Path $Root 'docker-compose.e2e.yml'))
$ComposePrefix = @('compose', '--env-file', $ComposeEnv, '-p', $Project) + $ComposeFiles
$TranscriptPath = Join-Path $Root 'e2e_run.txt'
$Passed = $false
$CurrentPhase = 'startup'

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $PreviousErrorActionPreference = $ErrorActionPreference
    $HasNativePreference = Test-Path variable:PSNativeCommandUseErrorActionPreference
    if ($HasNativePreference) {
        $PreviousNativePreference = $PSNativeCommandUseErrorActionPreference
    }
    try {
        $ErrorActionPreference = 'Continue'
        if ($HasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $false
        }
        $NativeOutput = & $FilePath @Arguments 2>&1
        $NativeExitCode = $LASTEXITCODE
        if ($NativeOutput) {
            $NativeOutput | ForEach-Object { Write-Host ([string]$_) }
        }
    } finally {
        $ErrorActionPreference = $PreviousErrorActionPreference
        if ($HasNativePreference) {
            $PSNativeCommandUseErrorActionPreference = $PreviousNativePreference
        }
    }
    if ($NativeExitCode -ne 0) {
        throw "$Label failed with exit code $NativeExitCode"
    }
}

function Invoke-DockerCompose {
    param([string[]]$Arguments, [string]$Label = 'docker compose')
    Invoke-Native -FilePath 'docker' -Arguments $Arguments -Label $Label
}

function Wait-Http {
    param([string]$Url, [string]$Label)
    $Deadline = (Get-Date).AddMinutes(3)
    while ((Get-Date) -lt $Deadline) {
        try {
            $Response = Invoke-WebRequest -Uri $Url -TimeoutSec 3 -UseBasicParsing
            if ($Response.StatusCode -eq 200) { Write-Host "PASS | $Label healthy"; return }
        } catch { Start-Sleep -Seconds 2 }
    }
    throw "$Label did not become healthy at $Url"
}

function Register-E2EUser {
    param([string]$Email, [string]$Name)
    $Body = @{ email = $Email; password = 'e2e-local-user-password-only'; full_name = $Name } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18001/api/auth/register' -ContentType 'application/json' -Body $Body | Out-Null
    } catch {
        # Kept stacks may already contain the deterministic account. Login verifies it below.
        try {
            Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18001/api/auth/login' -ContentType 'application/json' -Body (@{email=$Email; password='e2e-local-user-password-only'} | ConvertTo-Json) | Out-Null
        } catch { throw "Could not register or verify E2E user $Email" }
    }
}

Start-Transcript -Path $TranscriptPath -Append | Out-Null

try {
    Write-Host "Starting isolated Compose project '$Project' using ap-core:latest..."
    $CurrentPhase = 'build'
    Write-Host 'PHASE | build'
    Invoke-DockerCompose ($ComposePrefix + @('build')) 'E2E image build'
    Write-Host 'PASS | build'

    $CurrentPhase = 'up'
    Write-Host 'PHASE | up'
    Invoke-DockerCompose ($ComposePrefix + @('up', '-d')) 'E2E stack start'
    Write-Host 'PASS | up'

    $CurrentPhase = 'health'
    Write-Host 'PHASE | health'
    Wait-Http 'http://127.0.0.1:18001/health' 'Auth API'
    Wait-Http 'http://127.0.0.1:18000/health' 'Core API'
    Write-Host 'PASS | health'

    $CurrentPhase = 'migrations'
    Write-Host 'PHASE | migrations'
    Invoke-DockerCompose ($ComposePrefix + @('exec', '-T', 'auth', 'python', '-m', 'alembic', 'upgrade', 'head')) 'Auth migrations'
    Invoke-DockerCompose ($ComposePrefix + @('exec', '-T', 'core', 'uv', 'run', '--no-sync', 'alembic', 'upgrade', 'head')) 'Core migrations'
    Write-Host 'PASS | migrations'

    $CurrentPhase = 'users'
    Write-Host 'PHASE | users'
    Register-E2EUser 'admin@localhost' 'Synthetic E2E Admin'
    Register-E2EUser 'associate@localhost' 'Synthetic E2E Associate'
    $Sql = "UPDATE auth.users SET role = 'admin'::auth.user_role WHERE email = 'admin@localhost';"
    Invoke-DockerCompose ($ComposePrefix + @('exec', '-T', 'postgres', 'psql', '-v', 'ON_ERROR_STOP=1', '-U', 'ap_e2e_user', '-d', 'genworx_ap_e2e', '-c', $Sql))

    Write-Host 'PASS | users'
    $CurrentPhase = 'checks'
    Write-Host 'PHASE | checks'
    Write-Host 'Running API/GreenMail scenarios from AP-Core (tests.e2e.sample_documents import path)...'
    Push-Location $Core
    try {
        Invoke-Native -FilePath 'uv' -Arguments @('run', '--extra', 'dev', 'python', '-m', 'scripts.e2e_backend_check') -Label 'E2E checker'
        $Passed = $true
        Write-Host 'PASS | checks'
    } finally { Pop-Location }
} catch {
    Write-Host "FAIL | $CurrentPhase | $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if ($KeepStack) {
        Write-Host "DEBUG | Keeping isolated project '$Project' running."
    } else {
        Write-Host "Tearing down only isolated project '$Project' and its volumes..."
        try { Invoke-DockerCompose ($ComposePrefix + @('down', '--volumes', '--remove-orphans')) }
        catch { Write-Host "FAIL | isolated teardown | $($_.Exception.Message)" -ForegroundColor Red; $Passed = $false }
    }
    if ($Passed) { Write-Host 'E2E SUMMARY | PASS' -ForegroundColor Green }
    else { Write-Host 'E2E SUMMARY | FAIL' -ForegroundColor Red }
    Stop-Transcript | Out-Null
}

if (-not $Passed) { exit 1 }
