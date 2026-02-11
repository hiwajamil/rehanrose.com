# Patches Flutter's generated flutter_service_worker.js so it never calls
# cache.put() with a 206 (Partial Content) response. The Cache API does not
# support storing 206 responses, which causes "Failed to execute 'put' on
# 'Cache': Partial response (status code 206) is unsupported".
# Run after: flutter build web

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$swPath = Join-Path $scriptDir '..\build\web\flutter_service_worker.js'

if (-not (Test-Path $swPath)) {
  Write-Error "Not found: $swPath. Run 'flutter build web' first."
  exit 1
}

$content = Get-Content -Raw -LiteralPath $swPath

# 1) Fetch handler: only cache when response is not 206
$content = $content -replace "if \(response && Boolean\(response\.ok\)\) \{\s*cache\.put\(event\.request, response\.clone\(\)\);", "if (response && response.status !== 206 && Boolean(response.ok)) { cache.put(event.request, response.clone());"

# 2) Activate handler: two loops that copy from tempCache to contentCache
$content = $content -replace "var response = await tempCache\.match\(request\);\s*await contentCache\.put\(request, response\);", "var response = await tempCache.match(request);`n          if (response && response.status !== 206) await contentCache.put(request, response);"

# 3) onlineFirst: only cache when not 206 (match the indented one in onlineFirst)
$content = $content -replace "return caches\.open\(CACHE_NAME\)\.then\(\(cache\) => \{\s*cache\.put\(event\.request, response\.clone\(\)\);", "return caches.open(CACHE_NAME).then((cache) => {`n        if (response.status !== 206) cache.put(event.request, response.clone());"

Set-Content -LiteralPath $swPath -Value $content -NoNewline
Write-Host "Patched flutter_service_worker.js (skip cache for 206 responses)."
exit 0
