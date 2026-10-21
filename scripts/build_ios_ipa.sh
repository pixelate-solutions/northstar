#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="config/ios.release.env"
BUILD_ARGS=()

if [[ $# -gt 0 ]]; then
  if [[ "$1" == --* ]]; then
    BUILD_ARGS=("$@")
  else
    ENV_FILE="$1"
    BUILD_ARGS=("${@:2}")
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  cat >&2 <<EOF
Missing iOS release env file: $ENV_FILE

Create it from the checked-in template:
  cp config/ios.release.env.example config/ios.release.env

Then fill in the real publishable/client-safe values and rerun:
  scripts/build_ios_ipa.sh
EOF
  exit 1
fi

flutter pub get

(
  cd ios
  pod install
)

rm -rf build/native_assets/ios build/ios/archive build/ios/ipa

flutter build ios --release --no-codesign --dart-define-from-file="$ENV_FILE" ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}
flutter build ipa --release --dart-define-from-file="$ENV_FILE" ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"}

OBJECTIVE_C_BINARY="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/objective_c.framework/objective_c"
if [[ -f "$OBJECTIVE_C_BINARY" ]] && xcrun vtool -show-build "$OBJECTIVE_C_BINARY" | grep -q "platform IOSSIMULATOR"; then
  cat >&2 <<EOF
Invalid iOS archive: objective_c.framework was built for the iOS Simulator.

Run this script again from a clean build state:
  flutter clean
  scripts/build_ios_ipa.sh
EOF
  exit 1
fi

IPA_PATH="$(find build/ios/ipa -maxdepth 1 -name '*.ipa' | head -n 1)"
if [[ -n "$IPA_PATH" ]]; then
  TEMP_OBJECTIVE_C_BINARY="$(mktemp)"
  if unzip -p "$IPA_PATH" 'Payload/Runner.app/Frameworks/objective_c.framework/objective_c' >"$TEMP_OBJECTIVE_C_BINARY" 2>/dev/null; then
    if xcrun vtool -show-build "$TEMP_OBJECTIVE_C_BINARY" | grep -q "platform IOSSIMULATOR"; then
      rm -f "$TEMP_OBJECTIVE_C_BINARY"
      cat >&2 <<EOF
Invalid IPA: objective_c.framework was built for the iOS Simulator.

Run this script again from a clean build state:
  flutter clean
  scripts/build_ios_ipa.sh
EOF
      exit 1
    fi
  elif unzip -p "$IPA_PATH" 'Payload/Runner.app/Frameworks/App.framework/flutter_assets/NativeAssetsManifest.json' | grep -q 'objective_c.framework/objective_c'; then
    rm -f "$TEMP_OBJECTIVE_C_BINARY"
    cat >&2 <<EOF
Invalid IPA: NativeAssetsManifest.json references objective_c.framework, but the framework is missing.

Run this script again from a clean build state:
  flutter clean
  scripts/build_ios_ipa.sh
EOF
    exit 1
  fi
  rm -f "$TEMP_OBJECTIVE_C_BINARY"
fi
