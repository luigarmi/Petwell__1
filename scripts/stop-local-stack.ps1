$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force

Push-Location $repoRoot
try {
  docker compose down
} finally {
  Pop-Location
}

Write-Host "[petwell] Local stack stopped. Docker volumes were preserved."
