# Build Flutter web for production (rehanrose.com) with env from env.json.
# Run from gull_premium folder: .\build_web_production.ps1
# Then deploy: firebase deploy --only hosting

if (-not (Test-Path env.json)) {
  Write-Host "Create env.json first (copy from env.json.example and set SUPER_ADMIN_EMAIL)." -ForegroundColor Yellow
  exit 1
}
flutter build web --dart-define-from-file=env.json
if ($LASTEXITCODE -eq 0) {
  Write-Host "Build done. Deploy with: firebase deploy --only hosting" -ForegroundColor Green
}
