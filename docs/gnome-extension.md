# GNOME Shell Extension - Technical Documentation

This document provides technical details about the BluPlan Focus GNOME Shell extension implementation.

## Architecture Overview

The extension follows a modular architecture with clear separation of concerns:

```
extension.js (entry point)
    ├── dbusClient.js (BluPlan communication)
    ├── settingsManager.js (GSettings wrapper)
    └── panelButton.js (UI components)
```

### Component Responsibilities

#### extension.js
- Extension lifecycle management (enable/disable)
- Component initialization and cleanup
- Panel integration

#### dbusClient.js
- DBus proxy creation and management
- Signal subscription (focus_state_changed, timer_tick, focused_task_changed)
- Method invocations (start_focus, pause_focus, stop_focus, etc.)
- App availability monitoring
- Auto-launch functionality when BluPlan is not running

#### settingsManager.js
- GSettings schema loading and access
- Settings change notifications
- View mode logic (compact/expanded/custom)
- Element visibility management

#### panelButton.js
- Panel button UI (icon + timer + optional task name)
- Popup menu with controls and task information
- State synchronization with BluPlan
- Timer display updates
- Control button interactions

## DBus Interface

### BluPlan Service
- **Bus**: Session bus
- **Name**: `io.github.lab_gek.bluplan`
- **Path**: `/io/github/lab_gek/bluplan`
- **Interface**: `io.github.lab_gek.bluplan`

### Properties (Read-only)

| Property | Type | Description |
|----------|------|-------------|
| `focus_state` | `s` (string) | Current state: "idle", "working", "short_break", "long_break" |
| `focus_running` | `b` (boolean) | Whether timer is actively running (not paused) |
| `seconds_remaining` | `i` (int32) | Seconds remaining in current interval |
| `current_round` | `i` (int32) | Current pomodoro round number |
| `focused_item_id` | `s` (string) | ID of currently focused task (empty if none) |
| `focused_item_content` | `s` (string) | Name/content of focused task (empty if none) |

### Methods

#### start_focus(item_id: string) → void
Starts a focus session, optionally with a specific task. If `item_id` is empty, uses the auto-suggested task or previously focused task.

#### pause_focus() → void
Pauses the currently running focus session without losing state.

#### resume_focus() → void
Resumes a paused focus session.

#### stop_focus() → void
Stops the focus session completely and resets to idle state.

#### skip_break() → void
Skips the current break and immediately starts the next work interval.

#### complete_focused_task() → void
Marks the currently focused task as complete in BluPlan.

#### get_next_suggested_task() → string
Returns JSON representation of the next suggested task based on BluPlan's auto-suggest logic.

**Response format:**
```json
{
  "id": "task-id-string",
  "content": "Task name",
  "priority": 1,
  "due_date": "2026-02-21T10:00:00Z"
}
```

Returns `{}` if no task is suggested.

### Signals

#### focus_state_changed(state: string, running: boolean)
Emitted when focus state changes (idle ↔ working ↔ break) or when running/paused status changes.

#### timer_tick(seconds_remaining: int32)
Emitted every second during an active focus session. Provides updated countdown.

#### focused_task_changed(item_id: string, content: string)
Emitted when the focused task changes (user selects different task or task is cleared).

## Settings Schema

**Schema ID**: `org.gnome.shell.extensions.bluplan-focus`

### Keys

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `view-mode` | choice | `'expanded'` | Display mode: compact/expanded/custom |
| `show-timer` | boolean | `true` | Show timer in panel (custom mode) |
| `show-controls` | boolean | `true` | Show control buttons in menu |
| `show-task-name` | boolean | `true` | Show task name (custom mode) |
| `show-next-task` | boolean | `true` | Show next scheduled task in menu |
| `button-position` | choice | `'right'` | Panel position: left/center/right |

### View Mode Behavior

- **compact**: Only icon visible in panel
- **expanded**: Icon + timer + task name visible
- **custom**: Respects individual `show-*` settings

## State Synchronization

The extension maintains sync with BluPlan through:

1. **Initial Load**: When extension enables, queries all properties via DBus
2. **Signal Updates**: Subscribes to state/timer/task change signals
3. **Property Cache**: DBus proxy caches properties, updated on signal receipt
4. **Reconnection**: Watches for BluPlan availability, reconnects when app starts

### Reconnection Flow

```
Extension Enable
    ↓
Watch DBus Name (io.github.lab_gek.bluplan)
    ↓
Name Appears → Create Proxy → Subscribe Signals → Query State
    ↓
Name Vanishes → Clear Proxy → Show "Not Available"
    ↓
(User Interaction) → Launch App → Wait → Retry Connection
```

## UI Update Flow

```
DBus Signal Received
    ↓
Update Internal State (_currentState)
    ↓
    ├→ Update Icon (work/break/idle indicator)
    ├→ Update Timer Label (MM:SS format)
    ├→ Update Task Display (in menu and optionally panel)
    └→ Update Control Button States (show/hide, icon changes)
```

Timer updates occur every second via `timer_tick` signal, but icon/controls only update on state changes for efficiency.

## Error Handling

### DBus Connection Failures
- Extension shows "BluPlan not running" status
- Controls become non-functional but UI remains stable
- Auto-launch attempted on user interaction

### Method Call Failures
- Logged to console with `console.error()`
- UI doesn't crash; operation silently ignored
- User can retry action

### Schema Loading Failures
- Extension fails to enable with error thrown
- User sees notification about schema compilation needed

## Performance Considerations

1. **Timer Updates**: Only label text changes on tick, no full UI rebuild
2. **Property Caching**: DBus proxy caches properties, no repeated queries
3. **Conditional Rendering**: Elements not shown aren't created (not just hidden)
4. **Signal Throttling**: State changes already throttled by BluPlan (max 1/second)

## Testing DBus Interface

### Manual Testing Commands

```bash
# Check if BluPlan is available
gdbus introspect --session --dest io.github.lab_gek.bluplan \
    --object-path /io/github/lab_gek/bluplan

# Read focus state
gdbus call --session --dest io.github.lab_gek.bluplan \
    --object-path /io/github/lab_gek/bluplan \
    --method org.freedesktop.DBus.Properties.Get \
    io.github.lab_gek.bluplan focus_state

# Start focus session
gdbus call --session --dest io.github.lab_gek.bluplan \
    --object-path /io/github/lab_gek/bluplan \
    --method io.github.lab_gek.bluplan.start_focus ""

# Pause focus
gdbus call --session --dest io.github.lab_gek.bluplan \
    --object-path /io/github/lab_gek/bluplan \
    --method io.github.lab_gek.bluplan.pause_focus

# Monitor all signals
dbus-monitor "type='signal',sender='io.github.lab_gek.bluplan'"
```

### Automated Testing

Currently manual testing only. Future improvements could include:

- Unit tests for settingsManager logic
- Mock DBus service for UI testing
- Integration tests with test BluPlan instance

## Installation Steps (Technical)

1. **Schema Compilation**:
   ```bash
   glib-compile-schemas schemas/
   ```
   Generates `gschemas.compiled` file required by GSettings.

2. **File Placement**:
   ```
   ~/.local/share/gnome-shell/extensions/bluplan-focus@lab_gek.github.io/
   ├── extension.js
   ├── dbusClient.js
   ├── panelButton.js
   ├── settingsManager.js
   ├── prefs.js
   ├── metadata.json
   ├── stylesheet.css
   └── schemas/
       ├── org.gnome.shell.extensions.bluplan-focus.gschema.xml
       └── gschemas.compiled
   ```

3. **Extension Enable**:
   ```bash
   gnome-extensions enable bluplan-focus@lab_gek.github.io
   ```

4. **Shell Reload**:
   - X11: `Alt+F2` → `r` → Enter
   - Wayland: Logout/login

## Compatibility

- **GNOME Shell**: 45, 46, 47 (specified in metadata.json)
- **BluPlan**: Requires version with extended DBus interface (this implementation)
- **DBus**: Session bus required (standard in GNOME)

## Future Enhancements

Potential additions for future versions:

- [ ] Custom keybindings for controls
- [ ] Desktop notifications mirroring
- [ ] Quick add task from panel
- [ ] Multiple timer presets
- [ ] Visual timer ring/progress indicator
- [ ] Session stats display
- [ ] Configurable update intervals
- [ ] Theme-aware icon colors

## Debugging

### Enable Extension Logging

Extension logs go to journalctl:
```bash
journalctl -f -o cat /usr/bin/gnome-shell | grep -i bluplan
```

### Common Issues

**Extension not appearing**:
- Check enabled: `gnome-extensions list --enabled`
- Check errors: `gnome-extensions show bluplan-focus@lab_gek.github.io`
- Verify schema compiled: `ls schemas/gschemas.compiled`

**DBus calls failing**:
- Verify BluPlan running: `pgrep -f bluplan`
- Test interface: `gdbus introspect --session --dest io.github.lab_gek.bluplan --object-path /io/github/lab_gek/bluplan`
- Check service file: `ls ~/.local/share/dbus-1/services/io.github.lab_gek.bluplan.service`

**Settings not saving**:
- Verify schema installed: `gsettings list-schemas | grep bluplan`
- Check schema path: Extension must be in proper location for schema discovery

## Code Style

The extension follows GNOME Shell extension conventions:

- ES6 modules with explicit imports
- GObject-based class registration for UI components
- Async/await for DBus operations
- Camelcase for JavaScript, snake_case for DBus interface names
- Signal names with hyphens (JavaScript) vs underscores (DBus)

## License

GPL-3.0, same as BluPlan project.
