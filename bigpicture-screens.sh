#!/usr/bin/env bash
#
# bigpicture-console-mode
# Automatically switches displays + audio when Steam Big Picture opens/closes.
# Turns a KDE Plasma (Wayland) PC into a "console" hooked up to the TV.
#
# See README.md for full docs and how to adapt the config to your hardware.

export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# ============================================================================
#  CONFIGURATION  --  adapt to your machine (see README "Adapting to your hardware")
# ============================================================================

# Desktop displays (on outside Big Picture, off during Big Picture).
# Names come from: kscreen-doctor -o
DESKTOP_SCREENS=(DP-2 DP-4 DP-3)

# TV display (off on desktop, the only one on during Big Picture).
TV=HDMI-A-1

# Priority order of desktop displays when returning (the first = primary screen).
# Format: "OUTPUT:PRIORITY" -- see README.
SCREEN_PRIORITIES=(DP-2:1 DP-4:2 DP-3:3)

# Prefix of the TV audio sink (GPU HDMI).
# From: pw-dump | jq -r '.[] | select(.info.props."media.class"=="Audio/Sink") | .info.props."node.name"'
# We match by prefix because the suffix changes (hdmi-stereo / hdmi-stereo-extra2 ...).
AUDIO_TV_PREFIX="alsa_output.pci-0000_0c_00.1.hdmi"

# Prefix of the desktop audio sink (your usual interface / sound card).
AUDIO_DESKTOP_PREFIX="alsa_output.usb-Focusrite_Scarlett_Solo_USB"

# Exact title of the Big Picture window (from kdotool getwindowname).
BP_TITLE="Steam Big Picture Mode"

# Number of cycles (x2s) without Big Picture before switching back to desktop.
# Prevents false switches when a game comes to the foreground. 4 = ~8s.
HYSTERESIS=4

# ============================================================================
#  LOGIC  --  don't edit unless you know what you're doing
# ============================================================================

state="init"
missing=0
bt_last=""

# True if the Big Picture window is currently visible.
bp_visible() {
    local id
    for id in $(kdotool search --class steam); do
        [ "$(kdotool getwindowname "$id")" = "$BP_TITLE" ] && return 0
    done
    return 1
}

# Set as default the first sink whose node.name starts with $1.
# Retries up to 15s (the HDMI sink takes a moment to appear when the TV powers on).
set_audio_prefix() {
    local prefix="$1" id tries=0
    while [ $tries -lt 15 ]; do
        id=$(pw-dump | jq -r --arg p "$prefix" \
            '.[] | select(.info.props."media.class" == "Audio/Sink") | select(.info.props."node.name" | startswith($p)) | .id' \
            | head -1)
        if [ -n "$id" ]; then
            wpctl set-default "$id"
            return 0
        fi
        sleep 1
        tries=$((tries + 1))
    done
    echo "set_audio: sink not found for prefix $prefix (after 15 tries)" >&2
}

# Pick the audio output: a Bluetooth headset always takes priority,
# otherwise use the prefix passed as argument ($1).
pick_audio() {
    local fallback="$1" bt
    bt=$(pw-dump | jq -r \
        '.[] | select(.info.props."media.class" == "Audio/Sink") | select(.info.props."node.name" | startswith("bluez_output.")) | .info.props."node.name"' \
        | head -1)
    if [ -n "$bt" ]; then
        set_audio_prefix "$bt"
    else
        set_audio_prefix "$fallback"
    fi
}

# Back to desktop: turn displays on, turn TV off, restore order, desktop audio.
go_desktop() {
    local o
    for o in "${DESKTOP_SCREENS[@]}"; do kscreen-doctor output.$o.enable; done
    sleep 1
    kscreen-doctor output.$TV.disable
    sleep 1
    local args=()
    for pair in "${SCREEN_PRIORITIES[@]}"; do
        args+=("output.${pair%%:*}.priority.${pair##*:}")
    done
    kscreen-doctor "${args[@]}"
    pick_audio "$AUDIO_DESKTOP_PREFIX"
}

# Switch to Big Picture: turn TV on, turn desktop displays off, TV audio.
go_bigpicture() {
    local o
    kscreen-doctor output.$TV.enable
    sleep 1
    for o in "${DESKTOP_SCREENS[@]}"; do kscreen-doctor output.$o.disable; done
    pick_audio "$AUDIO_TV_PREFIX"
}

# Current audio sink based on state (used as fallback on BT disconnect).
current_fallback() {
    if [ "$state" = "bigpicture" ]; then
        echo "$AUDIO_TV_PREFIX"
    else
        echo "$AUDIO_DESKTOP_PREFIX"
    fi
}

while true; do
    if bp_visible; then
        missing=0
        if [ "$state" != "bigpicture" ]; then
            go_bigpicture
            state="bigpicture"
        fi
    else
        if [ "$state" = "bigpicture" ]; then
            missing=$((missing + 1))
            if [ $missing -ge $HYSTERESIS ]; then
                go_desktop
                state="desktop"
                missing=0
            fi
        elif [ "$state" != "desktop" ]; then
            go_desktop
            state="desktop"
        fi
    fi

    # Real-time Bluetooth monitoring (connect AND disconnect).
    bt_now=$(pw-dump | jq -r \
        '.[] | select(.info.props."media.class" == "Audio/Sink") | select(.info.props."node.name" | startswith("bluez_output.")) | .id' \
        | head -1)
    if [ -n "$bt_now" ] && [ "$bt_now" != "$bt_last" ]; then
        # Headset just connected -> switch to it.
        wpctl set-default "$bt_now"
    elif [ -z "$bt_now" ] && [ -n "$bt_last" ]; then
        # Headset just disconnected -> fall back to sink based on state.
        set_audio_prefix "$(current_fallback)"
    fi
    bt_last="$bt_now"

    sleep 2
done
