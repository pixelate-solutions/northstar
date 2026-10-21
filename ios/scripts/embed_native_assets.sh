#!/bin/sh

set -eu

case "${CONFIGURATION:-}" in
  Release|Profile) ;;
  *)
    exit 0
    ;;
esac

if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
  exit 0
fi

source_framework="${PROJECT_DIR}/../build/ios/iphoneos/Runner.app/Frameworks/objective_c.framework"
source_binary="${source_framework}/objective_c"
destination_framework="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks/objective_c.framework"

if [ ! -f "${source_binary}" ]; then
  echo "No device objective_c.framework found at ${source_framework}; skipping native asset embed."
  exit 0
fi

if xcrun vtool -show-build "${source_binary}" | grep -q "platform IOSSIMULATOR"; then
  echo "error: Refusing to embed simulator objective_c.framework in an iOS archive."
  exit 1
fi

mkdir -p "$(dirname "${destination_framework}")"
rm -rf "${destination_framework}"
ditto "${source_framework}" "${destination_framework}"

if [ "${CODE_SIGNING_ALLOWED:-}" = "YES" ] &&
   [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ] &&
   [ "${EXPANDED_CODE_SIGN_IDENTITY}" != "-" ]; then
  /usr/bin/codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" --timestamp=none "${destination_framework}"
fi
