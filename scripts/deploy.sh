#!/usr/bin/env bash
# FisherGO deploy script — builds with HK timestamp and deploys to Vercel production.
# Usage: bash scripts/deploy.sh
# (Run from the fishergo project root directory)

set -e

# Resolve project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "Loading .env..."
set -a && . .env && set +a

BUILD_TIME="$(TZ='Asia/Hong_Kong' date '+%Y-%m-%d %H:%M HKT')"
echo "Build time: $BUILD_TIME"

echo "Building web..."
flutter build web \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=BUILD_TIME="$BUILD_TIME"

echo "Deploying to Vercel production..."
vercel deploy build/web --prod --token="$VERCEL_TOKEN" --yes

echo "Done."