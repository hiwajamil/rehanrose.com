# Install dependencies and run Firebase/Google Cloud web sign-in fix.
# Use this when 'pip' and 'playwright' are not in PATH (e.g. Windows).

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "Installing Python dependencies (playwright)..." -ForegroundColor Cyan
python -m pip install -r requirements-firebase-fix.txt --quiet
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Installing Chromium for Playwright..." -ForegroundColor Cyan
python -m playwright install chromium
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "`nRunning firebase_web_fix.py...`n" -ForegroundColor Green
python firebase_web_fix.py
exit $LASTEXITCODE
