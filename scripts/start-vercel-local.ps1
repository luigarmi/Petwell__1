$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$publicProjectPath = Join-Path $repoRoot "apps/frontend-public-web"
$adminProjectPath = Join-Path $repoRoot "apps/frontend-admin-web"
$cloudflaredOut = Join-Path $repoRoot "cloudflared.out.log"
$cloudflaredErr = Join-Path $repoRoot "cloudflared.err.log"

function Wait-For-Api {
  param([string] $Url)

  for ($i = 0; $i -lt 60; $i++) {
    try {
      $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        return
      }
    } catch {
      Start-Sleep -Seconds 2
    }
  }

  throw "API did not become healthy at $Url"
}

function Get-CloudflaredCommand {
  $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $wingetPackage = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\Cloudflare.cloudflared_Microsoft.Winget.Source_8wekyb3d8bbwe\cloudflared.exe"
  if (Test-Path $wingetPackage) {
    return $wingetPackage
  }

  Write-Host "[petwell] cloudflared not found. Installing with winget..."
  winget install --id Cloudflare.cloudflared -e --accept-source-agreements --accept-package-agreements --silent

  if (Test-Path $wingetPackage) {
    return $wingetPackage
  }

  $cmd = Get-Command cloudflared -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  throw "cloudflared was not found after installation."
}

function Start-CloudflareTunnel {
  $cloudflared = Get-CloudflaredCommand

  Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
  Remove-Item -LiteralPath $cloudflaredOut, $cloudflaredErr -ErrorAction SilentlyContinue

  Write-Host "[petwell] Starting Cloudflare quick tunnel..."
  Start-Process `
    -FilePath $cloudflared `
    -ArgumentList @("tunnel", "--url", "http://localhost:80") `
    -RedirectStandardOutput $cloudflaredOut `
    -RedirectStandardError $cloudflaredErr `
    -WindowStyle Hidden

  for ($i = 0; $i -lt 60; $i++) {
    $logs = ""
    if (Test-Path $cloudflaredOut) {
      $logs += Get-Content $cloudflaredOut -Raw
    }
    if (Test-Path $cloudflaredErr) {
      $logs += Get-Content $cloudflaredErr -Raw
    }

    $match = [regex]::Match($logs, "https://[a-z0-9-]+\.trycloudflare\.com")
    if ($match.Success) {
      return $match.Value
    }

    Start-Sleep -Seconds 2
  }

  throw "Could not find the trycloudflare.com tunnel URL in cloudflared logs."
}

function Set-VercelApiUrl {
  param(
    [string] $ProjectPath,
    [string] $ApiUrl
  )

  Push-Location $ProjectPath
  try {
    Write-Host "[petwell] Updating Vercel NEXT_PUBLIC_API_URL for $ProjectPath"
    $ApiUrl | npx vercel env add NEXT_PUBLIC_API_URL production --force
  } finally {
    Pop-Location
  }
}

function Deploy-VercelProject {
  param([string] $ProjectPath)

  $projectFile = Join-Path $ProjectPath ".vercel/project.json"
  if (!(Test-Path $projectFile)) {
    throw "Missing $projectFile. Run a Vercel deploy/link for this project first."
  }

  $project = Get-Content $projectFile -Raw | ConvertFrom-Json
  $env:VERCEL_ORG_ID = $project.orgId
  $env:VERCEL_PROJECT_ID = $project.projectId

  Push-Location $repoRoot
  try {
    Write-Host "[petwell] Deploying $($project.projectName) to Vercel..."
    npx vercel deploy --prod --yes
  } finally {
    Pop-Location
    Remove-Item Env:\VERCEL_ORG_ID -ErrorAction SilentlyContinue
    Remove-Item Env:\VERCEL_PROJECT_ID -ErrorAction SilentlyContinue
  }
}

Push-Location $repoRoot
try {
  Write-Host "[petwell] Starting Docker Compose..."
  docker compose up -d

  Write-Host "[petwell] Waiting for local API..."
  Wait-For-Api "http://localhost/api/health/ready"

  $tunnelUrl = Start-CloudflareTunnel
  $apiUrl = "$tunnelUrl/api"

  Write-Host "[petwell] Tunnel URL: $tunnelUrl"
  Write-Host "[petwell] Waiting for tunneled API..."
  Wait-For-Api "$apiUrl/health/ready"

  Set-VercelApiUrl $publicProjectPath $apiUrl
  Set-VercelApiUrl $adminProjectPath $apiUrl

  Deploy-VercelProject $publicProjectPath
  Deploy-VercelProject $adminProjectPath

  Write-Host ""
  Write-Host "[petwell] Ready."
  Write-Host "Public: https://petwell-public.vercel.app"
  Write-Host "Admin:  https://petwell-admin.vercel.app/admin/login"
  Write-Host "API:    $apiUrl"
  Write-Host ""
  Write-Host "Keep this PC on and Docker/cloudflared running while using Vercel."
} finally {
  Pop-Location
}
