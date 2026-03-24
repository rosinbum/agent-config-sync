#!/usr/bin/env bash
# Install acs to ~/.local/bin/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${HOME}/.local/bin"

mkdir -p "$INSTALL_DIR"
cp "${SCRIPT_DIR}/acs" "${INSTALL_DIR}/acs"
chmod +x "${INSTALL_DIR}/acs"

echo "Installed acs → ${INSTALL_DIR}/acs"

if ! echo "$PATH" | tr ':' '\n' | grep -qx "$INSTALL_DIR"; then
  echo ""
  echo "Add to your PATH if not already:"
  echo "  export PATH=\"${INSTALL_DIR}:\$PATH\""
fi
