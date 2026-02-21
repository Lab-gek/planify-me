# GNOME Shell Extension Quick Start

## Overview

The BluPlan Focus GNOME Shell extension brings your Pomodoro timer to the GNOME Shell top bar, allowing you to control focus sessions without switching windows.

## Features at a Glance

| Feature | Description |
|---------|-------------|
| **Live Timer** | Real-time countdown display in top bar |
| **State Indicator** | Visual icon showing work/break/idle status |
| **Quick Controls** | Start, pause, stop, complete from dropdown menu |
| **Task Display** | Current & next task preview |
| **Auto-Launch** | Extension launches BluPlan when needed |
| **Configurable** | 3 display modes + custom element visibility |

## Display Modes

### Compact Mode
**Top Bar:** `[Icon]`
- Minimal space usage
- Icon indicates state only

### Expanded Mode (Default)
**Top Bar:** `[Icon] 25:00 Focus Task Name`
- Timer display
- Current task name (truncated)
- Full information at a glance

### Custom Mode
**Top Bar:** Configurable
- Pick individual elements to show
- Fine-tune your display

## Quick Installation

```bash
cd gnome-shell-extension
./install.sh
gnome-extensions enable bluplan-focus@lab_gek.github.io
```

**Restart GNOME Shell:**
- **X11**: Press `Alt+F2`, type `r`, press Enter
- **Wayland**: Log out and back in

## Configuration

Open settings via:
- GNOME Extensions app → BluPlan Focus → Settings button
- Command: `gnome-extensions prefs bluplan-focus@lab_gek.github.io`

### Available Settings

| Setting | Options | Description |
|---------|---------|-------------|
| **View Mode** | Compact / Expanded / Custom | Overall display style |
| **Show Timer** | On / Off | Display countdown in panel |
| **Show Task Name** | On / Off | Display current task |
| **Show Controls** | On / Off | Show control buttons in menu |
| **Show Next Task** | On / Off | Display next scheduled task |
| **Button Position** | Left / Center / Right | Panel placement |

## Usage

### Starting a Focus Session

1. **From Extension Menu:**
   - Click extension icon in top bar
   - Click "Start" button
   - Uses auto-suggested task or last focused task

2. **From Next Task:**
   - Open extension menu
   - Click on the next task preview
   - Starts focus session with that task

3. **From BluPlan App:**
   - Select task and start focus
   - Extension automatically syncs

### Control Buttons

| Button | Icon | Action |
|--------|------|--------|
| **Play/Pause** | ▶️/⏸️ | Start or pause timer |
| **Stop** | ⏹️ | End session completely |
| **Complete** | ✓ | Mark focused task as done |

### Status Indicators

| Icon | Meaning |
|------|---------|
| ⏰ | Working (timer active) |
| ⏸️ | Paused or idle |
| ✓ | On break |

## How It Works

The extension communicates with BluPlan via **DBus**:

```
Extension ←→ DBus ←→ BluPlan App
```

- **State sync**: Extension queries and subscribes to BluPlan's focus state
- **Timer updates**: Received every second via DBus signal
- **Commands**: Extension sends start/pause/stop commands to app
- **Auto-launch**: If BluPlan isn't running, extension starts it

All timer logic lives in BluPlan; the extension is a lightweight display/control interface.

## Troubleshooting

### Extension doesn't appear
```bash
# Check if enabled
gnome-extensions list --enabled | grep bluplan

# Enable manually
gnome-extensions enable bluplan-focus@lab_gek.github.io

# Check for errors
journalctl -f -o cat /usr/bin/gnome-shell | grep -i bluplan
```

### Shows "BluPlan not running"
- Normal when app isn't active
- Click extension or use any control to auto-launch
- Verify: `pgrep -f bluplan` should show process after launch

### Controls don't work
```bash
# Verify DBus interface exists
gdbus introspect --session \
  --dest io.github.lab_gek.bluplan \
  --object-path /io/github/lab_gek/bluplan

# Test manual command
gdbus call --session \
  --dest io.github.lab_gek.bluplan \
  --object-path /io/github/lab_gek/bluplan \
  --method io.github.lab_gek.bluplan.start_focus ""
```

### Settings not working
```bash
# Verify schema compiled
ls gnome-shell-extension/schemas/gschemas.compiled

# Recompile if needed
cd gnome-shell-extension
glib-compile-schemas schemas/
```

## Advanced Usage

### DBus Testing

Monitor all BluPlan DBus signals:
```bash
dbus-monitor "type='signal',sender='io.github.lab_gek.bluplan'"
```

Query current state:
```bash
gdbus call --session \
  --dest io.github.lab_gek.bluplan \
  --object-path /io/github/lab_gek/bluplan \
  --method org.freedesktop.DBus.Properties.GetAll \
  io.github.lab_gek.bluplan
```

### Custom Styling

Edit `~/.local/share/gnome-shell/extensions/bluplan-focus@lab_gek.github.io/stylesheet.css`:

```css
.bluplan-timer-label {
    font-weight: bold;
    color: #ff6b6b; /* Custom color */
    font-size: 12pt;
}
```

Reload GNOME Shell to apply changes.

## Uninstallation

```bash
gnome-extensions disable bluplan-focus@lab_gek.github.io
rm -rf ~/.local/share/gnome-shell/extensions/bluplan-focus@lab_gek.github.io
```

## Technical Documentation

For developers and advanced users:
- [Full Technical Documentation](gnome-extension.md)
- [Extension README](../gnome-shell-extension/README.md)

## Support & Feedback

- **Issues**: [GitHub Issues](https://github.com/alainm23/planify/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alainm23/planify/discussions)

## Requirements

- GNOME Shell 45, 46, or 47
- BluPlan installed with extended DBus interface
- DBus session bus access (standard on GNOME)

---

**Quick Links:**
- [Installation Guide](../gnome-shell-extension/README.md)
- [Technical Details](gnome-extension.md)
- [Main Project](../README.md)
