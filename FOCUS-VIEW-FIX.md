# Focus View & Extension Sync Fix

## Issues Fixed

### 1. Extension Not Showing Current Task
**Problem:** Extension showed "No task selected" even when a task was being worked on.

**Root Cause:** BluPlan needed to be restarted for the new DBus properties to take effect. The old running instance didn't have the updated `focused_item_content` property.

**Solution:** The DBus interface was already correctly implemented in the previous update. Simply restart BluPlan to activate the new properties.

### 2. Focus View Layout Improvements
**Problem:** Current task and upcoming tasks had the same visual weight, making it hard to distinguish what you're working on now vs. what's next.

**Changes Made:**

#### Visual Hierarchy
- **Current Task**: Larger heading ("Title-3" font), more padding (18px margin), more prominent display
- **Upcoming Tasks**: Smaller caption heading, compact display, slightly dimmed (80% opacity)
- **Hover Effect**: Upcoming tasks brighten on hover to indicate they're clickable

#### Styling Updates ([data/resources/stylesheet/focus.css](data/resources/stylesheet/focus.css))

```css
/* Compact upcoming tasks styling */
listbox.compact-rows row {
	min-height: 36px;
	padding: 4px 8px;
}

listbox.compact-rows row .compact-task-row {
	opacity: 0.8;
	font-size: 0.9em;
}

listbox.compact-rows row:hover {
	opacity: 1;
	background: alpha(@accent_color, 0.1);
	cursor: pointer;
}

/* Make current task more prominent */
.boxed-list row:not(.compact-task-row) {
	padding: 12px;
	min-height: 48px;
}
```

#### Layout Changes ([src/Views/Focus.vala](src/Views/Focus.vala))

**Current Task Section:**
- Heading: "Current Task" with `title-3` and `font-bold` styles
- Card: Full-size ItemRow with edit mode enabled
- Spacing: 18px margin below for visual separation

**Upcoming Tasks Section:**
- Heading: "Upcoming Tasks" with `caption-heading` and `dim-label` styles  
- List: Compact ItemRow instances with reduced padding
- Hover: Clickable with visual feedback
- Empty state: Centered "No upcoming tasks" message

## How to Apply the Fix

### Step 1: Restart BluPlan

**Option A - Kill and Restart:**
```bash
# Stop the running instance
pkill -f io.github.lab_gek.bluplan

# Start the new version
cd /home/toplap/Documents/Personal/planify-me/build
export LD_LIBRARY_PATH=$PWD/core:$LD_LIBRARY_PATH
./src/io.github.lab_gek.bluplan
```

**Option B - Restart GNOME Extension (if installed):**
```bash
gnome-extensions disable bluplan-focus@lab_gek.github.io
gnome-extensions enable bluplan-focus@lab_gek.github.io
```

### Step 2: Test the Changes

1. **Open BluPlan** and go to the Focus view
2. **Add some tasks** with today's date (if you don't have any)
3. **Start a focus session** with one task
4. **Verify the layout:**
   - Current task should be displayed prominently with larger text
   - Upcoming tasks should be smaller and slightly dimmed
   - Hovering over upcoming tasks should highlight them
5. **Check the GNOME extension** (if installed):
   - Should now show the actual focused task name (not "No task selected")
   - "Next Task" should show a different task than the current one

## Visual Comparison

### Before:
```
Current Task            ← Same font size
┌─────────────────┐
│ Enable sync...  │
└─────────────────┘

Upcoming Tasks          ← Same font size
┌─────────────────┐
│ Set timely...   │
│ Another task    │
└─────────────────┘
```

### After:
```
CURRENT TASK            ← Larger, prominent
┌──────────────────────┐
│  Enable sync...      │  ← More padding
└──────────────────────┘

upcoming tasks          ← Smaller, dimmed
┌─────────────────┐
│ Set timely...   │   ← Compact, clickable
│ Another task    │
└─────────────────┘
```

## Expected Results

### In BluPlan Focus View:
✅ Current task stands out with larger heading and more space  
✅ Upcoming tasks are clearly secondary with compact styling  
✅ Tasks are interactive - click any upcoming task to focus on it  
✅ Visual feedback on hover shows tasks are clickable  

### In GNOME Extension:
✅ Shows the actual focused task name (not "No task selected")  
✅ "Next Task" shows the first upcoming task (different from current)  
✅ Timer displays correctly  
✅ All controls work properly  

## Troubleshooting

### Extension Still Shows "No task selected"

**Possible causes:**
1. BluPlan not restarted after rebuild
2. Extension not reloaded after BluPlan restart
3. DBus connection issue

**Solutions:**
```bash
# 1. Verify BluPlan is running the new version
pgrep -a io.github.lab_gek.bluplan

# 2. Check DBus interface
gdbus introspect --session \
  --dest io.github.lab_gek.bluplan \
  --object-path /io/github/lab_gek/bluplan | grep Focused

# Should show:
# readonly s FocusedItemId = '';
# readonly s FocusedItemContent = '';

# 3. Restart GNOME Shell (on X11)
# Press Alt+F2, type 'r', press Enter

# Or logout/login (on Wayland)
```

### Upcoming Tasks Not Showing

**Possible causes:**
1. No tasks scheduled for today
2. All tasks are completed

**Solutions:**
1. Add tasks with today's date
2. Uncheck completed tasks to make them active again
3. Schedule existing tasks for today

## Technical Details

### DBus Properties (Already Implemented)

From [src/Services/DBusServer.vala](src/Services/DBusServer.vala):
```vala
public string focused_item_content {
    owned get {
        var item = Services.FocusManager.get_default ().focus_item;
        return item != null ? item.content : "";
    }
}
```

Property notifications on change:
```vala
focus_manager.focus_item_changed.connect (() => {
    var item = focus_manager.focus_item;
    focused_task_changed (
        item != null ? item.id : "",
        item != null ? item.content : ""
    );
    notify_property ("focused-item-id");
    notify_property ("focused-item-content");
});
```

### CSS Class Application

Compact styling is applied via CSS classes:
- `compact-rows` on the upcoming tasks listbox
- `compact-task-row` on individual upcoming task rows
- Default styling remains on current task row

The ItemRow widget respects the compact styling while maintaining full functionality.

## Build Information

- **Build Time:** 2026-02-21 15:55
- **Binary Size:** 6.9 MB
- **Modified Files:**
  - src/Views/Focus.vala (layout improvements)
  - data/resources/stylesheet/focus.css (compact styling)
  - src/Services/DBusServer.vala (already had correct properties)

## Next Steps

After restarting BluPlan, the extension should automatically detect and display:
1. The currently focused task name
2. The next suggested task (first from upcoming list)
3. Timer and state information

No code changes needed to the extension - it's already correctly listening to the DBus properties!
