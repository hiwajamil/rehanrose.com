#!/usr/bin/env bash
# Build Flutter web for production (rehanrose.com) with env from env.json.
# Run from gull_premium folder: ./build_web_production.sh
# Then deploy: firebase deploy --only hosting

set -e
if [ ! -f env.json ]; then
  echo "Create env.json first (copy from env.json.example and set SUPER_ADMIN_EMAIL)."
  exit 1
fi
flutter build web --dart-define-from-file=env.json
echo "Build done. Deploy with: firebase deploy --only hosting"
