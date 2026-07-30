#!/usr/bin/env bash
#
# Installer for bigpicture-console-mode.
# Copies the script + service, checks dependencies, enables the service.
#
# Usage: ./install.sh

set -e

SCRIPT_SRC="bigpicture-screens.sh"
SERVICE_SRC="bigpicture-screens.service"
BIN_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"

echo "==> Installing bigpicture-console-mode"

# --- Dependency check --------------------------------------------------------
echo "==> Checking dependencies..."
MISSING=()
for cmd in kscreen-doctor wpctl pw-dump jq kdotool; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        MISSING+=("$cmd")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo "   Missing dependencies: ${MISSING[*]}"
    echo "   Install them first, for example:"
    echo "     paru -S kdotool jq"
    echo "   (kscreen-doctor, wpctl and pw-dump ship with KDE Plasma / PipeWire)"
    echo
    read -rp "   Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborting."; exit 1; }
fi

# --- Copy the script ---------------------------------------------------------
echo "==> Copying script to $BIN_DIR"
mkdir -p "$BIN_DIR"
cp "$SCRIPT_SRC" "$BIN_DIR/bigpicture-screens.sh"
chmod +x "$BIN_DIR/bigpicture-screens.sh"

# --- Copy the service --------------------------------------------------------
echo "==> Copying service to $SERVICE_DIR"
mkdir -p "$SERVICE_DIR"
cp "$SERVICE_SRC" "$SERVICE_DIR/bigpicture-screens.service"

# --- Enable ------------------------------------------------------------------
echo "==> Enabling systemd user service"
systemctl --user daemon-reload
systemctl --user enable --now bigpicture-screens.service

echo
echo "==> Done!"
echo "    Check status with:"
echo "      systemctl --user status bigpicture-screens.service"
echo
echo "    IMPORTANT: this script contains values specific to YOUR machine"
echo "    (display names, audio sinks). If your hardware changed, edit the"
echo "    CONFIGURATION block at the top of $BIN_DIR/bigpicture-screens.sh"
echo "    then run: systemctl --user restart bigpicture-screens.service"
