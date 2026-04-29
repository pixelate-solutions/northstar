#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-config/ios.release.env}"

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

flutter build ipa --release --dart-define-from-file="$ENV_FILE" "${@:2}"
