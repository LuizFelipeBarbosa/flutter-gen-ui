#!/usr/bin/env bash
set -euo pipefail

flutter_version="${FLUTTER_VERSION:-3.44.4}"
flutter_install_dir="${FLUTTER_INSTALL_DIR:-$HOME/flutter-$flutter_version}"

if [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  export PATH="$FLUTTER_ROOT/bin:$PATH"
elif [ "${NETLIFY:-}" != "true" ] && command -v flutter >/dev/null 2>&1; then
  :
else
  if [ ! -x "$flutter_install_dir/bin/flutter" ]; then
    git clone --depth 1 --branch "$flutter_version" \
      https://github.com/flutter/flutter.git \
      "$flutter_install_dir"
  fi

  export PATH="$flutter_install_dir/bin:$PATH"
fi

flutter --version
flutter config --enable-web
flutter clean
flutter pub get

build_args=(web --release --pwa-strategy=none)

append_dart_define() {
  local name="$1"
  local value="${!name:-}"

  if [ -n "$value" ]; then
    build_args+=(--dart-define="$name=$value")
  fi
}

for name in \
  INCEPTION_API_KEY \
  GOOGLE_PLACES_API_KEY \
  GOOGLE_MAPS_API_KEY \
  KEY_511 \
  BART_API_KEY \
  BART_PROXY_BASE_URL \
  GEMINI_API_KEY \
  FEATHERLESS_API_KEY
do
  append_dart_define "$name"
done

flutter build "${build_args[@]}"
