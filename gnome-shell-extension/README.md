# BluPlan Focus - GNOME Shell Extension

A GNOME Shell extension that displays BluPlan's Pomodoro timer and task status directly in your top bar.

## Features

- **Live Timer Display**: See the countdown timer in the top bar
- **Focus State Indicator**: Visual icon showing work/break status
- **Quick Controls**: Start, pause, stop, and complete tasks from the menu
- **Next Task Preview**: View your next scheduled task
- **Highly Configurable**: Choose exactly what you want to see
- **Auto-Launch**: Extension automatically launches BluPlan when needed

## Display Modes

- **Compact**: Icon only - minimal space usage
- **Expanded**: Icon + timer + current task name
- **Custom**: Pick and choose which elements to show

## Installation

### From Source

1. **Compile the GSettings schema:**
   ```bash
   cd gnome-shell-extension
   glib-compile-schemas schemas/
   ```

2. **Copy to extensions directory:**
   ```bash
   mkdir -p ~/.local/share/gnome-shell/extensions/bluplan-focus@lab_gek.github.io
   cp -r * ~/.local/share/gnome-shell/extensions/bluplan-focus@lab_gek.github.io/
   ```

3. **Restart GNOME Shell:**
   - On X11: Press `Alt+F2`, type `r`, and press Enter
   - On Wayland: Log out and log back in

4. **Enable the extension:**
   ```bash
   gnome-extensions enable bluplan-focus@lab_gek.github.io
   ```
   
   Or use GNOME Extensions app.

### Using the Installation Script

```bash
cd gnome-shell-extension
./install.sh
```

## Configuration

Open GNOME Extensions app and click the settings button next to "BluPlan Focus", or run:

```bash
gnome-extensions prefs bluplan-focus@lab_gek.github.io
```

### Available Settings

- **View Mode**: Choose between Compact, Expanded, or Custom display
- **Show Timer**: Display countdown in the panel
- **Show Task Name**: Display currently focused task
- **Show Controls**: Show start/pause/stop/complete buttons in menu
- **Show Next Task**: Display next scheduled task suggestion
- **Button Position**: Place button on left, center, or right of top bar

## Requirements

- GNOME Shell 45 or later
- BluPlan (io.github.lab_gek.bluplan) installed
- DBus session bus access

## How It Works

The extension communicates with BluPlan via DBus, using BluPlan's focus management API. The main app maintains all state and timer logic, while the extension provides a convenient display and control interface.

When you click controls in the extension, it sends commands to BluPlan. All state changes are broadcast via DBus signals, keeping the extension display in sync in real-time.

## Troubleshooting

**Extension doesn't appear:**
- Make sure BluPlan is installed and the main app runs successfully
- Check extension is enabled: `gnome-extensions list --enabled`
- Check logs: `journalctl -f -o cat /usr/bin/gnome-shell`

**Extension shows "BluPlan not running":**
- The extension will auto-launch BluPlan when you interact with it
- Make sure `io.github.lab_gek.bluplan.desktop` file is in applications directory
- Check: `ls ~/.local/share/applications/io.github.lab_gek.bluplan.desktop`

**Controls don't work:**
- Ensure BluPlan has the extended DBus interface (version with focus API)
- Test DBus manually: `gdbus call --session --dest io.github.lab_gek.bluplan --object-path /io/github/lab_gek/bluplan --method io.github.lab_gek.bluplan.start_focus ""`

## Development

### Testing DBus Commands

```bash
# Get focus state
gdbus introspect --session --dest io.github.lab_gek.bluplan --object-path /io/github/lab_gek/bluplan

# Start focus session
gdbus call --session --dest io.github.lab_gek.bluplan --object-path /io/github/lab_gek/bluplan --method io.github.lab_gek.bluplan.start_focus ""

# Pause focus
gdbus call --session --dest io.github.lab_gek.bluplan --object-path /io/github/lab_gek/bluplan --method io.github.lab_gek.bluplan.pause_focus

# Monitor signals
gdbus monitor --session --dest io.github.lab_gek.bluplan
```

### Debugging

Enable extension logging:
```bash
# Watch extension logs
journalctl -f -o cat | grep "BluPlan Focus"
```

Check for errors:
```bash
dbus-monitor "type='signal',sender='io.github.lab_gek.bluplan'"
```

## License

This extension is part of the BluPlan project and follows the same GPL-3.0 license.

## Credits

Extension created for [BluPlan](https://github.com/alainm23/planify) by Alain M.
