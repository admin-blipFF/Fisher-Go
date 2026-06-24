#!/usr/bin/env bash
set -euo pipefail

export FLUTTER_HOME="${FLUTTER_HOME:-/tmp/flutter}"
export PATH="$FLUTTER_HOME/bin:$PATH"

if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
  git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "$FLUTTER_HOME"
fi

cat > .env <<ENV
SUPABASE_URL=${SUPABASE_URL:-}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-}
VECTOR_ENGINE_API_KEY=${VECTOR_ENGINE_API_KEY:-}
ENV

BUILD_TIME="$(TZ='Asia/Hong_Kong' date '+%Y-%m-%d %H:%M HKT')"

flutter config --enable-web
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}" \
  --dart-define=BUILD_TIME="$BUILD_TIME"
