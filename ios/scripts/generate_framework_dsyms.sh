#!/bin/sh

set -eu

case "${CONFIGURATION:-}" in
  Release|Profile) ;;
  *)
    exit 0
    ;;
esac

if [ -z "${DWARF_DSYM_FOLDER_PATH:-}" ]; then
  echo "Skipping native framework dSYM generation: DWARF_DSYM_FOLDER_PATH is not set."
  exit 0
fi

if [ -z "${TARGET_BUILD_DIR:-}" ] || [ -z "${WRAPPER_NAME:-}" ]; then
  echo "Skipping native framework dSYM generation: build paths are incomplete."
  exit 0
fi

framework_path="${TARGET_BUILD_DIR}/${WRAPPER_NAME}/Frameworks/objective_c.framework"
binary_path="${framework_path}/objective_c"
dsym_path="${DWARF_DSYM_FOLDER_PATH}/objective_c.framework.dSYM"

if [ ! -f "${binary_path}" ]; then
  echo "No objective_c framework binary found at ${binary_path}; skipping dSYM generation."
  exit 0
fi

if [ -f "${dsym_path}/Contents/Resources/DWARF/objective_c" ]; then
  echo "objective_c framework dSYM already present at ${dsym_path}."
  exit 0
fi

mkdir -p "${DWARF_DSYM_FOLDER_PATH}"

echo "Generating dSYM for ${binary_path}"
xcrun dsymutil "${binary_path}" -o "${dsym_path}" || {
  echo "warning: Failed to generate objective_c.framework dSYM."
  exit 0
}

if [ -f "${dsym_path}/Contents/Resources/DWARF/objective_c" ]; then
  echo "Generated ${dsym_path}"
else
  echo "warning: objective_c.framework dSYM was not generated as expected."
fi
