# Focus Mode / Current Task Roadmap
# Forget about compiling your in a sandbox
Date: 2026-02-20

## Goal
Add a dedicated **Focus** experience with:
- a current-task page users can enter/leave at any time,
- inline task editing while focusing (title, notes, subtasks),
- Pomodoro timer with work/break cycles,
- points integration that avoids unfair late penalties caused by Pomodoro breaks.

## Product Decisions
- **Entry point**: Sidebar filter item (`Focus`) like Inbox/Today.
- **Task selection**: Auto-suggest current scheduled task + manual override.
- **Pomodoro defaults**: 25m work / 5m short break / 15m long break / 4 rounds.
- **Points integration**:
  - bonus points for focused task completion,
  - break time contributes to effective grace period.

## Implemented in current pass
- Focus filter + navigation wiring in sidebar and main window.
- New `Views.Focus` page with timer, controls, current task editing, note editing, subtask creation.
- New `Services.FocusManager` with start/pause/resume/stop/skip-break and auto-suggestion.
- Focus settings keys and Focus settings page (`FocusSetting`).
- Initial points integration with persisted focus session state.

## Remaining Work

### Phase A — Start focus from task rows
1. Add a "Focus on this task" action in task row context menu and/or row action button.
2. On activation:
   - set focus item in `FocusManager`,
   - navigate to Focus view.

### Phase B — Session polish
1. Desktop notifications for:
   - work interval ended,
   - break ended.
2. Optional sound/vibration hooks where available.
3. Better empty state actions (task picker dialog).

### Phase C — UI polish
1. Add dedicated Focus CSS styles for timer prominence and state colors.
2. Improve visual progress indicator (ring/bar + state badges).
3. Add subtle active-focus indicator in other views.

### Phase D — Data resilience
1. Restore active timer/session safely across app restarts.
2. Clear stale focus item references when item is deleted/archived/completed.
3. Validate behavior when focused item moves between projects/sections.

### Phase E — Points tuning
1. Confirm expected point outcomes in edge cases:
   - no due end time,
   - long break crossing due end,
   - skipped breaks.
2. Add focused-task completion tests around grace-period extension.

### Phase F — QA / validation
1. Build + run full app check.
2. Manual test matrix:
   - start/pause/resume/stop,
   - work→break→work transitions,
   - auto-suggest and manual override,
   - task title/notes/subtask edits,
   - points bonus and grace extension.
3. Internationalization pass for newly added strings.

## Suggested Next Implementation Slice
- Task-row "Focus on this task" action.
- Notifications at interval boundaries.
- Focus CSS for better visual hierarchy.


Phase 1 — Core Infrastructure

Add FOCUS to PaneType enum in Enum.vala. Add a new FocusState enum with values IDLE, WORKING, SHORT_BREAK, LONG_BREAK.

Create Objects.Filters.Focus singleton — new file core/Objects/Filters/Focus.vala. Follow the pattern of existing filters (e.g., Today). view_id = "focus-view", icon = a timer/hourglass icon, name = "Focus". Register in meson.build alongside other filter files.

Add Focus GSettings keys in io.github.lab_gek.bluplan.gschema.xml:

focus-work-duration (int, default 25) — work interval in minutes
focus-short-break (int, default 5) — short break in minutes
focus-long-break (int, default 15) — long break in minutes
focus-rounds-before-long-break (int, default 4)
focus-bonus-points (int, default 2) — bonus points per completed focus session
focus-current-item-id (string, default "") — persists the currently focused task across restarts
Add "focus" to the default views-order-visible array
Create Services.FocusManager — new file src/Services/FocusManager.vala. Singleton service managing:

Current focused Objects.Item?
Pomodoro state machine: IDLE → WORKING → SHORT_BREAK → WORKING → ... → LONG_BREAK → cycle
GLib.Timer for elapsed tracking + Timeout.add_seconds(1, ...) for per-second UI ticks
Signals: timer_tick(int seconds_remaining), state_changed(FocusState state), session_completed(int round), focus_item_changed(Objects.Item? item)
Methods: start(), pause(), resume(), stop(), skip_break(), set_focus_item(Objects.Item)
Tracks total_break_seconds accumulated during the current focus session (for grace period extension)
Auto-suggest logic: query Services.Store for items with due.datetime overlapping "now"
Register in meson.build
Phase 2 — Focus View (the page)

Create Views.Focus — new file src/Views/Focus.vala. Layout (top to bottom):

Layouts.HeaderBar with title "Focus" and controls (stop button, settings gear)
Timer section: Large circular progress indicator showing countdown, current state label ("Working" / "Short Break" / "Long Break"), round indicator (e.g., "2 of 4")
Current time display: Show wall clock time + estimated end time of current session
Task section: If a task is focused — show task title (editable), description/notes (editable Gtk.TextView), subtask list with ability to add new subtasks, labels, priority, due info. If no task — show "No task selected" with an auto-suggest card or a "Pick a task" button
Controls: Play/Pause, Stop, Skip Break buttons (contextual based on state)
Register in meson.build
Wire Focus view into MainWindow at MainWindow.vala:

Add add_focus_view() method following the lazy-create pattern (like add_today_view())
Add "focus-view" case to pane_selected handler
Set a longer cache timeout (Focus view should persist while active session is running)
Add Focus to the sidebar in Sidebar.vala:

Add Objects.Filters.Focus.get_default() to both build_filters_flowbox() and build_filters_listbox()
Add corresponding SidebarRow in Sidebar.vala so users can show/hide/reorder it
Phase 3 — Task Row Integration

Add "Focus on this" action to task rows. In ItemRow.vala (or wherever the item context menu is built):
Add a "Focus on this task" menu item / small icon button
On activation: call Services.FocusManager.get_default().set_focus_item(item) and navigate to focus view via EventBus.pane_selected(PaneType.FOCUS, "focus")
Phase 4 — Points Integration

Modify points grace period logic in Item.vala calculate_points():

When completing a task during a focus session, add FocusManager.total_break_seconds to the grace period before calculating late penalties
Award focus-bonus-points extra points when a task is completed during an active focus session
Add EventBus signals in EventBus.vala:

focus_started(Objects.Item item)
focus_stopped(Objects.Item? item)
These allow other parts of the app to react (e.g., show a subtle indicator)
Phase 5 — Styling & Polish

Add Focus-specific CSS in a new file data/resources/stylesheet/focus.css:

Circular timer progress ring styles
State-specific color theming (work = accent color, break = green/calm)
Large typography for timer countdown
Import it in index.css and register in io.github.lab_gek.bluplan.gresource.xml
Add icon for Focus filter — add an SVG icon (e.g., timer or crosshair/target icon) to icons and register in gresource XML.

Phase 6 — Preferences

Add Focus settings page in Preferences — new file src/Dialogs/Preferences/Pages/FocusSetting.vala:
Work duration spinner (1-60 min)
Short break spinner (1-30 min)
Long break spinner (1-60 min)
Rounds before long break spinner (1-10)
Bonus points spinner
Auto-suggest toggle
Register in PreferencesWindow.vala and meson.build
Phase 7 — Notifications

Desktop notifications for state transitions — when a work period ends or a break ends, send a GLib.Notification so the user knows even if they left the app. Use the existing notification pattern from the app.
Verification
Unit test: Add a test in test for FocusManager state machine transitions and timer logic
Manual test (sidebar): Confirm Focus appears in sidebar, can be shown/hidden/reordered in Preferences → Sidebar
Manual test (Pomodoro): Start a focus session, verify timer counts down, transitions through work → break → work cycles correctly
Manual test (task editing): While focused, edit task title, add subtask, add notes — verify changes persist
Manual test (auto-suggest): Create a task with a due time in the current window, open Focus page, verify it's suggested
Manual test (points): Complete a task during focus with breaks, verify grace period is extended by total break time and bonus points are awarded
Build: meson compile -C builddir must pass with all new files
Decisions
Sidebar filter over floating button/overlay — consistent with existing UI patterns
Auto-suggest + manual override — Focus page suggests the currently-scheduled task but user can pick any task
Standard Pomodoro defaults (25/5/15) with full configurability in settings
Break time added to grace period — avoids penalizing users whose "lateness" is caused by Pomodoro breaks
Bonus points for focus session completion — motivates use of the feature
Separate preferences page for Focus settings rather than cramming into existing TaskSetting page
New files summary
File	Type
core/Objects/Filters/Focus.vala	Filter singleton
src/Services/FocusManager.vala	Pomodoro state machine + timer
src/Views/Focus.vala	Focus page view
src/Dialogs/Preferences/Pages/FocusSetting.vala	Focus preferences
data/resources/stylesheet/focus.css	Focus-specific styles
Modified files summary
File	Change
Enum.vala	Add FOCUS to PaneType, add FocusState enum
meson.build	Register Focus filter
EventBus.vala	Add focus signals
Item.vala	Modify calculate_points() for focus grace period
io.github.lab_gek.bluplan.gschema.xml	Add focus settings keys
io.github.lab_gek.bluplan.gresource.xml	Register CSS + icon
index.css	Import focus.css
meson.build	Register new source files
MainWindow.vala	Add add_focus_view() + pane_selected case
Sidebar.vala	Add Focus filter to both sidebar modes
ItemRow.vala	Add "Focus on this" action
Sidebar.vala	Add Focus to sidebar config
PreferencesWindow.vala	Register FocusSetting page