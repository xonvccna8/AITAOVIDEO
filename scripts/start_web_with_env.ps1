param(
    [int]$Port = 5173,
    [switch]$OpenBrowser
)

. "$PSScriptRoot\env_helpers.ps1"

$local = Assert-LocalEnv
Push-Location $local.Root
try {
    Write-Host ""
    Write-Host "TOAN HOC 4.0 - React/Vite web" -ForegroundColor Cyan
    Write-Host "Using env: $($local.Path)" -ForegroundColor DarkGray
    Write-Host ""

    if (-not (Test-Path -LiteralPath "node_modules")) {
        Write-Host "[1/2] Installing npm dependencies..." -ForegroundColor Yellow
        npm install
        if ($LASTEXITCODE -ne 0) {
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "[1/2] npm dependencies already installed" -ForegroundColor Green
    }

    $url = "http://127.0.0.1:$Port/"
    Write-Host "[2/2] Starting Vite dev server at $url" -ForegroundColor Yellow
    Write-Host "AI video endpoint: /api/ai-video/generate" -ForegroundColor DarkGray
    Write-Host ""

    if ($OpenBrowser) {
        Start-Process $url | Out-Null
    }

    npm run dev -- --port $Port
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
