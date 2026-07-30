# bigpicture-console-mode

Turns a **KDE Plasma 6 (Wayland)** PC into a "console" when Steam Big Picture
launches: it automatically switches both **displays** and **audio** to the TV,
then restores everything when you exit.

Built for a multi-monitor + TV setup, with automatic priority given to a Bluetooth headset.

## What it does

- **Big Picture launched** → the TV turns on (alone), the desktop displays turn off, sound moves to the TV. Games launched from Big Picture therefore all land on the TV.
- **Big Picture closed** → the desktop displays turn back on, the priority order (primary screen) is restored, the TV turns off, sound returns to the desktop output.
- **Bluetooth headset connected** → it takes audio priority, whether you're in Big Picture or on the desktop. Disconnected → sound falls back to the TV (in Big Picture) or the desktop output.
- **Anti-flicker in games**: a hysteresis prevents the displays from flickering when a game comes to the foreground and briefly hides Big Picture.

Everything runs as a **systemd user service**, started automatically on login.

## Dependencies

- `kscreen-doctor` (ships with KDE Plasma)
- `wpctl` and `pw-dump` (ship with PipeWire / WirePlumber)
- `jq`
- `kdotool` (Wayland window detection)

On CachyOS / Arch:

```bash
paru -S kdotool jq
```

(the rest ships with Plasma and PipeWire)

## Installation

```bash
git clone https://github.com/GeoffreyVogel1/bigpicture-console-mode.git
cd bigpicture-console-mode
./install.sh
```

The installer copies the script to `~/.local/bin/`, the service to
`~/.config/systemd/user/`, and enables the service.

Check it's running:

```bash
systemctl --user status bigpicture-screens.service
```

## ⚠️ Adapting to your hardware

The script contains **hardware-specific values** (display names, audio sinks).
They're grouped in the `CONFIGURATION` block at the top of `bigpicture-screens.sh`.
If you reinstall on the **same hardware**, nothing to change. Otherwise, update these values.

### Finding display names

```bash
kscreen-doctor -o
```

Spot the outputs (`HDMI-A-1`, `DP-2`, `DP-3`, `DP-4`...). Put the TV in `TV=`
and the desktop displays in `DESKTOP_SCREENS`. Set the desired order (the `:1` = primary
screen) in `SCREEN_PRIORITIES`.

### Finding audio sinks

```bash
pw-dump | jq -r '.[] | select(.info.props."media.class"=="Audio/Sink") | .info.props."node.name"'
```

- The **HDMI** output looks like `alsa_output.pci-0000_0c_00.1.hdmi-stereo`.
  ⚠️ The suffix (`hdmi-stereo`, `hdmi-stereo-extra2`...) changes depending on which displays
  are active, so we only keep the stable **prefix**: `alsa_output.pci-0000_0c_00.1.hdmi`.
  → put it in `AUDIO_TV_PREFIX`.
- The **desktop** output (interface / sound card) → put it in `AUDIO_DESKTOP_PREFIX`
  (a prefix is enough here too).

### Checking the Big Picture window title

Launch Big Picture, then:

```bash
kdotool search --class steam | while read id; do kdotool getwindowname "$id"; done
```

You should see `Steam Big Picture Mode`. If Steam changes this title one day, update it
in `BP_TITLE`.

After any change:

```bash
systemctl --user restart bigpicture-screens.service
```

## Usage

Nothing to do day to day: launch Steam Big Picture as usual, everything switches on its own.
For a true "sit down and everything's on the TV" mode, you can create a shortcut that runs
`steam -bigpicture`.

## Troubleshooting

Watch the logs live:

```bash
journalctl --user -u bigpicture-screens.service -f
```

- **"sink not found for prefix ..."** → the audio prefix doesn't match any sink.
  Re-check `AUDIO_TV_PREFIX` / `AUDIO_DESKTOP_PREFIX` with the `pw-dump` command above.
- **Displays flicker in games** → increase `HYSTERESIS` (e.g. `6` = ~12s).
- **Already-playing sound doesn't switch** → expected: only streams started *after* the
  switch follow the default-output change. A game launched from Big Picture starts after,
  so it correctly plays on the TV.
- **Nothing happens when launching Big Picture** → check that `bp_visible` actually detects
  the window (the `kdotool` command in the "title" section above).

## Uninstall

```bash
./uninstall.sh
```

## How it works (technical summary)

A systemd user service runs a loop that, every 2 seconds:

1. checks whether the `Steam Big Picture Mode` window is visible (via `kdotool`);
2. switches displays (`kscreen-doctor`) + audio (`wpctl set-default`) based on state;
3. applies a hysteresis to ignore brief disappearances of Big Picture;
4. monitors Bluetooth headset connect/disconnect to give it audio priority.

Audio sinks are resolved by **`node.name` prefix** (via `pw-dump | jq`) because the ID
and suffix change depending on which outputs are active.

## License

MIT — do whatever you want with it.
