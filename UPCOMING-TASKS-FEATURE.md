# Upcoming Tasks Feature Implementation

## Overview
Fixed the task synchronization between the BluPlan Focus feature and the GNOME Shell extension by implementing a proper "upcoming tasks" system.

## Problem
The GNOME extension's "next task" and the current "working on" task were not syncing properly because:
- The task suggestion logic returned the best task to work on "right now"
- It didn't exclude the currently focused task
- There was no concept of a queue or upcoming tasks

## Solution

### 1. Enhanced FocusManager (src/Services/FocusManager.vala)

#### New Method: `get_suggested_focus_items()`
```vala
public Gee.ArrayList<Objects.Item> get_suggested_focus_items (int max_items = 5)
```

This method:
- Returns a list of up to 5 suggested tasks
- **Automatically excludes the currently focused task**
- Prioritizes tasks in this order:
  1. Scheduled tasks that are happening right now (between start and end time)
  2. Today's scheduled tasks
  3. Other tasks due today
- Prevents duplicates in the list

#### Modified: `suggest_focus_item()`
Now simply returns the first item from `get_suggested_focus_items()`, ensuring consistent behavior.

### 2. Updated DBus Interface (src/Services/DBusServer.vala)

#### Enhanced Method: `get_next_suggested_task()`
Now returns the first **upcoming** task (excluding the current focus_item), so the extension shows what's actually coming next.

#### New Method: `get_upcoming_tasks()`
```vala
public string get_upcoming_tasks () throws IOError, DBusError
```

Returns a JSON array of up to 5 upcoming tasks, allowing clients to display a full list:
```json
[
  {
    "id": "task-id-1",
    "content": "Task name",
    "priority": 1,
    "due_date": "2026-02-21T14:30:00"
  },
  ...
]
```

### 3. Focus View Enhancement (src/Views/Focus.vala)

#### New "Upcoming Tasks" Section
Added a visual section below the current task that shows:
- The next 5 suggested tasks
- "No upcoming tasks" message when the list is empty
- Click any upcoming task to make it the current focus item

#### Implementation Details:
- New `upcoming_listbox` widget displays the task list
- New `update_upcoming_tasks()` method populates the list
- Tasks are clickable - clicking sets them as the current focus item
- List updates automatically when the focus item changes

## User Benefits

### In BluPlan App
1. **Better Task Planning**: See what's coming up next while working on current task
2. **Quick Task Switching**: Click any upcoming task to focus on it
3. **Clear Workflow**: Understand your task queue at a glance

### In GNOME Extension
1. **Accurate "Next Task"**: The extension now shows the actual next task (not the current one)
2. **Proper Sync**: "Working on" and "Next" task are always different and properly coordinated
3. **Consistent Logic**: Both app and extension use the same task suggestion algorithm

## How It Works

### Task Priority Algorithm
1. **Active Scheduled Tasks**: Tasks with a time range that includes "now"
2. **Today's Scheduled Tasks**: Tasks scheduled for today but not yet active
3. **Today's Tasks**: Other tasks due today

### Exclusion Logic
- The current `focus_item` is always excluded from suggestions
- Already-completed tasks are excluded
- Archived tasks are excluded
- Duplicates are prevented

### Example Scenario
```
Current Focus: "Write documentation"

Upcoming Tasks:
1. "Review pull request" (scheduled 2:00 PM - 3:00 PM)
2. "Team meeting" (scheduled 3:00 PM)
3. "Update tests"
4. "Fix bug #123"
5. "Code review"
```

When you complete "Write documentation", the top task from the upcoming list automatically becomes the next suggestion.

## Technical Details

### Modified Files
1. **src/Services/FocusManager.vala**
   - Added `get_suggested_focus_items()` method
   - Modified `suggest_focus_item()` to use new method

2. **src/Services/DBusServer.vala**
   - Updated `get_next_suggested_task()` to exclude current item
   - Added `get_upcoming_tasks()` DBus method

3. **src/Views/Focus.vala**
   - Added `upcoming_listbox` widget
   - Added `update_upcoming_tasks()` method
   - Added click handlers for upcoming tasks

### API Changes

#### New DBus Method Available
```
Method: io.github.lab_gek.bluplan.get_upcoming_tasks
Returns: string (JSON array)
```

Can be called via:
```bash
gdbus call --session \
  --dest io.github.lab_gek.bluplan \
  --object-path /io/github/lab_gek/bluplan \
  --method io.github.lab_gek.bluplan.get_upcoming_tasks
```

## Testing

### Manual Testing Steps
1. **Launch BluPlan** and navigate to Focus view
2. **Add some tasks** with today's dates
3. **Select a task** for focus (or use "Use Suggested Task")
4. **Verify** the "Upcoming Tasks" section shows other tasks
5. **Click** an upcoming task to switch focus
6. **Verify** the list updates and excludes the new current task

### GNOME Extension Testing
1. **Enable the extension** (if installed)
2. **Start a focus session** in BluPlan
3. **Check the top bar** shows the current task name
4. **Verify** "Next Task" shows a different task (not the current one)
5. **Complete the current task**
6. **Verify** the extension updates to show the next task

## Future Enhancements

Possible improvements:
1. **Manual Reordering**: Drag-and-drop to reorder upcoming tasks
2. **Custom Filters**: Filter upcoming tasks by project/label
3. **Time Estimates**: Show estimated time for each upcoming task
4. **Smart Scheduling**: AI-powered task ordering based on deadlines and priority
5. **Task Queue Presets**: Save and load different task queue configurations

## Migration Notes

### For Users
- No action required - the feature is automatic
- Existing focus sessions continue to work
- The extension will automatically show better task suggestions

### For Developers
- The `suggest_focus_item()` method signature unchanged (backward compatible)
- New `get_suggested_focus_items()` method available for client code
- DBus API expanded (existing methods still work)

## Revision History
- **2026-02-21**: Initial implementation
  - Added upcoming tasks list to Focus view
  - Enhanced task suggestion algorithm
  - Updated DBus interface
