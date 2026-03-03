#!/usr/bin/env bash
# Build and deploy to Firebase with env.json so rehanrose.com works like local (super admin, Google sign-in, etc.).
# Run from repo root: ./gull_premium/deploy_to_firebase.sh
# Or from gull_premium: ./deploy_to_firebase.sh

set -e
cd "$(dirname "$0")"

if [ ! -f env.json ]; then
  echo "env.json not found. Copy from env.json.example and set SUPER_ADMIN_EMAIL, GOOGLE_WEB_CLIENT_ID, etc."
  exit 1
fi

echo "Building web with env.json (so super admin & sign-in work on rehanrose.com)..."
flutter build web --dart-define-from-file=env.json

echo "Deploying to Firebase..."
firebase deploy

echo "Done. App is live at https://gull-48040.web.app"
