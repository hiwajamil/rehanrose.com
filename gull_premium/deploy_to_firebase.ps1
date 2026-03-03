# Build and deploy to Firebase with env.json so rehanrose.com works like local (super admin, Google sign-in, etc.).
# Run from repo root: .\gull_premium\deploy_to_firebase.ps1
# Or from gull_premium: .\deploy_to_firebase.ps1

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

if (-not (Test-Path env.json)) {
  Write-Host "env.json not found. Copy from env.json.example and set SUPER_ADMIN_EMAIL, GOOGLE_WEB_CLIENT_ID, etc." -ForegroundColor Yellow
  exit 1
}

Write-Host "Building web with env.json (so super admin & sign-in work on rehanrose.com)..." -ForegroundColor Cyan
flutter build web --dart-define-from-file=env.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Deploying to Firebase..." -ForegroundColor Cyan
firebase deploy
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Done. App is live at https://gull-48040.web.app" -ForegroundColor Green
