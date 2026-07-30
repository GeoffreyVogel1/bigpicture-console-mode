#!/usr/bin/env bash
#
# Uninstaller for bigpicture-console-mode.
# Stops/disables the service and removes the files.

set -e

BIN_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"

echo "==> Disabling service"
systemctl --user disable --now bigpicture-screens.service 2>/dev/null || true

echo "==> Removing files"
rm -f "$BIN_DIR/bigpicture-screens.sh"
rm -f "$SERVICE_DIR/bigpicture-screens.service"

systemctl --user daemon-reload

echo "==> Done. The service and script have been removed."
echo "    (Your displays stay in their current state; reconfigure them via"
echo "     System Settings > Display if needed.)"
