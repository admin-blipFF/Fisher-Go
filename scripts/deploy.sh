#!/usr/bin/env bash
# FisherGO deploy script — builds with HK timestamp and deploys to Vercel production.
# Usage: bash scripts/deploy.sh
# (Run from the fishergo project root directory)

set -euo pipefail

# Resolve project root (parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

if [ -n "$(git status --porcelain)" ]; then
  echo "Production deployment requires a clean Git worktree." >&2
  exit 1
fi

if [ -f .env ]; then
  echo "Loading .env..."
  set -a && . .env && set +a
else
  echo "No .env file; using the current environment."
fi

: "${VERCEL_TOKEN:?VERCEL_TOKEN is required for production deployment}"
: "${SUPABASE_URL:?SUPABASE_URL is required for production deployment}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is required for production deployment}"
: "${SUPABASE_PROJECT_REF:?SUPABASE_PROJECT_REF is required for production deployment}"
dart run tool/verify_supabase_project_identity.dart
dart run tool/verify_public_release_config.dart

ACCOUNT_DELETION_ENABLED="${FISHERGO_ACCOUNT_DELETION_ENABLED:-false}"
case "$ACCOUNT_DELETION_ENABLED" in
  true|false) ;;
  *)
    echo "FISHERGO_ACCOUNT_DELETION_ENABLED must be true or false." >&2
    exit 1
    ;;
esac

BUILD_TIME="$(TZ='Asia/Hong_Kong' date '+%Y-%m-%d %H:%M HKT')"
BUILD_ID="$(TZ='Asia/Hong_Kong' date '+%Y%m%d%H%M%S')"
GIT_SHA="${FISHERGO_GIT_SHA:-$(git rev-parse HEAD 2>/dev/null || printf 'unknown')}"
APP_VERSION="$(sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' pubspec.yaml | head -n 1)"
if [ -z "${FISHERGO_RELEASE_ID:-}" ]; then
  if [ "$GIT_SHA" = "unknown" ]; then
    RELEASE_ID="${APP_VERSION:-unknown}-${BUILD_ID}"
  else
    RELEASE_ID="${APP_VERSION:-unknown}-${GIT_SHA:0:12}"
  fi
else
  RELEASE_ID="$FISHERGO_RELEASE_ID"
fi

RELEASE_PROVENANCE_FILE="$PROJECT_ROOT/.fishergo-deploy-release-id"
printf '%s\n' "$RELEASE_ID" > "$RELEASE_PROVENANCE_FILE"
cleanup_release_provenance() {
  rm -f "$RELEASE_PROVENANCE_FILE"
}
trap cleanup_release_provenance EXIT
echo "Build time: $BUILD_TIME"

echo "Building web..."
flutter build web \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=FISHERGO_PRIVACY_URL="${FISHERGO_PRIVACY_URL:-}" \
  --dart-define=FISHERGO_SUPPORT_EMAIL="${FISHERGO_SUPPORT_EMAIL:-}" \
  --dart-define=FISHERGO_ANALYTICS_ENABLED="${FISHERGO_ANALYTICS_ENABLED:-false}" \
  --dart-define=FISHERGO_ACCOUNT_DELETION_ENABLED="$ACCOUNT_DELETION_ENABLED" \
  --dart-define=FISHERGO_MAPLIBRE=true \
  --dart-define=FISHERGO_RELEASE_ID="$RELEASE_ID" \
  --dart-define=BUILD_TIME="$BUILD_TIME"

printf '{"build_id":"%s","build_time":"%s"}\n' \
  "$BUILD_ID" "$BUILD_TIME" > build/web/version.json

FISHERGO_BUILD_ID="$BUILD_ID" \
FISHERGO_BUILD_TIME="$BUILD_TIME" \
FISHERGO_GIT_SHA="$GIT_SHA" \
FISHERGO_RELEASE_ID="$RELEASE_ID" \
dart run tool/write_release_manifest.dart build/web/release-manifest.json

dart run tool/check_client_artifacts_for_secrets.dart build/web

VERCEL_PROJECT="${VERCEL_PROJECT:-fishergo}"
PUBLIC_URL="${FISHERGO_PUBLIC_URL:-https://fisher-go.app}"
PUBLIC_ALIAS_URL="${FISHERGO_PUBLIC_ALIAS_URL:-https://www.fisher-go.app}"
PRIMARY_DOMAIN="$(printf '%s' "$PUBLIC_URL" | sed -E 's#^https?://##; s#/.*##')"
ALIAS_DOMAIN="$(printf '%s' "$PUBLIC_ALIAS_URL" | sed -E 's#^https?://##; s#/.*##')"
if [[ $PRIMARY_DOMAIN != "fisher-go.app" ||
  $ALIAS_DOMAIN != "www.fisher-go.app" ]]; then
  echo "Production deploy only permits fisher-go.app and www.fisher-go.app aliases." >&2
  exit 1
fi

echo "Deploying to Vercel production..."
DEPLOY_OUTPUT="$(npx --yes vercel deploy . --prod \
  --project="$VERCEL_PROJECT" \
  --token="$VERCEL_TOKEN" \
  --build-env="SUPABASE_URL=$SUPABASE_URL" \
  --build-env="SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  --build-env="SUPABASE_PROJECT_REF=$SUPABASE_PROJECT_REF" \
  --build-env="FISHERGO_PRIVACY_URL=${FISHERGO_PRIVACY_URL:-}" \
  --build-env="FISHERGO_SUPPORT_EMAIL=${FISHERGO_SUPPORT_EMAIL:-}" \
  --build-env="FISHERGO_ANALYTICS_ENABLED=${FISHERGO_ANALYTICS_ENABLED:-false}" \
  --build-env="FISHERGO_ACCOUNT_DELETION_ENABLED=$ACCOUNT_DELETION_ENABLED" \
  --build-env="FISHERGO_DEPLOY_RELEASE_ID=$RELEASE_ID" \
  --build-env="FISHERGO_RELEASE_ID=$RELEASE_ID" \
  --build-env="FISHERGO_GIT_SHA=$GIT_SHA" \
  --yes 2>&1)"
printf '%s\n' "$DEPLOY_OUTPUT"

DEPLOYMENT_URL="$(printf '%s\n' "$DEPLOY_OUTPUT" \
  | grep -Eo 'https://[^[:space:]]+\.vercel\.app' \
  | tail -n 1 || true)"
if [ -z "$DEPLOYMENT_URL" ]; then
  echo "Could not determine the Vercel production deployment URL." >&2
  exit 1
fi

for DOMAIN in "$PRIMARY_DOMAIN" "$ALIAS_DOMAIN"; do
  echo "Promoting $DEPLOYMENT_URL to $DOMAIN..."
  npx --yes vercel alias set "$DEPLOYMENT_URL" "$DOMAIN" \
    --token="$VERCEL_TOKEN"
done

echo "Verifying public aliases and secret asset boundary..."
dart run tool/verify_deployed_web.dart \
  --url="$PUBLIC_URL" \
  --alias="$PUBLIC_ALIAS_URL" \
  --release-id="$RELEASE_ID"

echo "Done."
