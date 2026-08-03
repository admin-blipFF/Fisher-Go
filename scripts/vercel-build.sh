#!/usr/bin/env bash
set -euo pipefail

export FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter}"
export PATH="$FLUTTER_HOME/bin:$PATH"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "$FLUTTER_HOME"
fi

# Production must use the verified remote registry and server boundaries. Keep
# preview/local builds usable without Supabase for map and UI diagnostics.
if [ "${VERCEL_ENV:-preview}" = "production" ] ||
  [ "${FISHERGO_REQUIRE_SUPABASE:-false}" = "true" ]; then
  required_production_vars=(
    SUPABASE_URL
    SUPABASE_ANON_KEY
    SUPABASE_PROJECT_REF
    FISHERGO_PRIVACY_URL
    FISHERGO_SUPPORT_EMAIL
  )
  missing_production_vars=()
  for variable_name in "${required_production_vars[@]}"; do
    if [ -z "${!variable_name:-}" ]; then
      missing_production_vars+=("$variable_name")
    fi
  done
  if [ "${#missing_production_vars[@]}" -gt 0 ]; then
    printf 'Missing required production Vercel environment variables: %s\n' \
      "${missing_production_vars[*]}" >&2
    exit 1
  fi
fi

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
GIT_SHA="${FISHERGO_GIT_SHA:-${VERCEL_GIT_COMMIT_SHA:-${GITHUB_SHA:-unknown}}}"
APP_VERSION="$(sed -n 's/^version:[[:space:]]*\([^[:space:]#]*\).*/\1/p' pubspec.yaml | head -n 1)"
DEPLOY_RELEASE_ID=""
if [ -f .fishergo-deploy-release-id ]; then
  DEPLOY_RELEASE_ID="$(tr -d '\r\n' < .fishergo-deploy-release-id)"
fi
if [ -n "$DEPLOY_RELEASE_ID" ]; then
  RELEASE_ID="$DEPLOY_RELEASE_ID"
elif [ -n "${FISHERGO_DEPLOY_RELEASE_ID:-}" ]; then
  # The deploy command passes this uniquely named value so a stale project-level
  # FISHERGO_RELEASE_ID cannot silently replace the release being promoted.
  RELEASE_ID="$FISHERGO_DEPLOY_RELEASE_ID"
elif [ -z "${FISHERGO_RELEASE_ID:-}" ]; then
  if [ "$GIT_SHA" = "unknown" ]; then
    RELEASE_ID="${APP_VERSION:-unknown}-${BUILD_ID}"
  else
    RELEASE_ID="${APP_VERSION:-unknown}-${GIT_SHA:0:12}"
  fi
else
  RELEASE_ID="$FISHERGO_RELEASE_ID"
fi

flutter config --enable-web
flutter pub get
if [ "${VERCEL_ENV:-preview}" = "production" ] ||
  [ "${FISHERGO_REQUIRE_SUPABASE:-false}" = "true" ]; then
  dart run tool/verify_supabase_project_identity.dart
  dart run tool/verify_public_release_config.dart
fi
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
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

BUILD_ID="$BUILD_ID" node <<'JS'
const fs = require('fs');

const path = 'build/web/flutter_bootstrap.js';
const buildId = process.env.BUILD_ID;
const text = fs.readFileSync(path, 'utf8');
let next = text.replace(
  '"mainJsPath":"main.dart.js"',
  `"mainJsPath":"main.dart.js?v=${buildId}"`,
);
if (next === text) {
  throw new Error('Unable to version main.dart.js in flutter_bootstrap.js');
}
const serviceWorkerStart = next.lastIndexOf('_flutter.loader.load({');
if (serviceWorkerStart === -1) {
  throw new Error('Unable to disable Flutter service worker in flutter_bootstrap.js');
}
next = `${next.slice(0, serviceWorkerStart)}_flutter.loader.load();\n`;
fs.writeFileSync(
  path,
  next,
);
JS
