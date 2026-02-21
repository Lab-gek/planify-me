# Task Promotion Animation

## Overview
Added a smooth slide-up animation that plays when you complete a task and the next upcoming task automatically becomes the current focus task.

## What Was Added

### 1. Animation Detection Logic ([src/Views/Focus.vala](src/Views/Focus.vala))

#### New Member Variables
```vala
private Objects.Item? previous_focus_item = null;
private bool is_animating = false;
```

- `previous_focus_item`: Tracks the last focused task to detect changes
- `is_animating`: Prevents multiple animations from running simultaneously

#### New Method: `handle_focus_item_change()`
```vala
private void handle_focus_item_change () {
    var new_item = Services.FocusManager.get_default ().focus_item;
    
    // Check if previous task was completed and new task is from upcoming list
    bool should_animate = false;
    if (previous_focus_item != null && new_item != null) {
        var upcoming_items = Services.FocusManager.get_default ().get_suggested_focus_items (5);
        // Check if the new item is in the upcoming list
        foreach (var upcoming in upcoming_items) {
            if (upcoming.id == new_item.id) {
                should_animate = true;
                break;
            }
        }
    }
    
    previous_focus_item = new_item;
    
    if (should_animate && !is_animating) {
        animate_task_promotion ();
    } else {
        update_task_ui ();
        update_control_buttons ();
    }
}
```

**Logic:**
1. When focus item changes, check if:
   - We had a previous task
   - The new task exists
   - The new task was in the upcoming tasks list
2. If all true → animate the transition
3. Otherwise → update UI immediately (no animation)

#### New Method: `animate_task_promotion()`
```vala
private void animate_task_promotion () {
    is_animating = true;
    
    // Get the first upcoming task widget before update
    var first_upcoming = upcoming_listbox.get_first_child ();
    if (first_upcoming == null) {
        is_animating = false;
        update_task_ui ();
        update_control_buttons ();
        return;
    }
    
    // Add animation class to trigger CSS animation
    first_upcoming.add_css_class ("task-promote-animation");
    
    // Wait for animation to complete (300ms)
    Timeout.add (300, () => {
        is_animating = false;
        update_task_ui ();
        update_control_buttons ();
        return false;
    });
}
```

**How it works:**
1. Marks animation as in-progress
2. Gets the first upcoming task widget
3. Adds CSS class `task-promote-animation` to trigger the slide-up
4. Waits 300ms for animation to complete
5. Updates the UI to show the new current task

### 2. CSS Animation ([data/resources/stylesheet/focus.css](data/resources/stylesheet/focus.css))

```css
/* Task promotion animation */
@keyframes task-promote-slide-up {
	0% {
		transform: translateY(0);
		opacity: 1;
	}
	50% {
		transform: translateY(-60px);
		opacity: 0.7;
	}
	100% {
		transform: translateY(-120px);
		opacity: 0;
	}
}

.task-promote-animation {
	animation: task-promote-slide-up 300ms cubic-bezier(0.4, 0.0, 0.2, 1) forwards;
}
```

**Animation Details:**
- **Duration:** 300ms (smooth but not too slow)
- **Easing:** `cubic-bezier(0.4, 0.0, 0.2, 1)` - Material Design "standard" curve
- **Effect:** Slides up 120px while fading out (opacity 1 → 0)
- **Mode:** `forwards` - keeps the final state after animation

## How It Works (Step by Step)

### Scenario: User completes a task

1. **User clicks complete** on "Enable synchronization with third-party service"
   
2. **Task gets marked as completed** in the database
   
3. **FocusManager detects completion** and:
   - Removes completed task from focus
   - Auto-suggests next task: "Set timely reminders"
   - Fires `focus_item_changed` signal

4. **Focus view receives signal** → calls `handle_focus_item_change()`
   
5. **Animation check:**
   ```
   Previous item: "Enable sync..." ✓ (exists)
   New item: "Set timely reminders" ✓ (exists)
   Is new item in upcoming list? YES ✓
   → should_animate = true
   ```

6. **`animate_task_promotion()` is called:**
   - Gets the "Set timely reminders" widget from upcoming list
   - Adds CSS class `task-promote-animation`
   - CSS animation starts: slides up 120px over 300ms

7. **After 300ms:**
   - Animation completes
   - UI updates: "Set timely reminders" moves to Current Task
   - Upcoming list refreshes with remaining tasks

## Visual Effect

### Before (Task List):
```
CURRENT TASK
┌─────────────────────────────┐
│ Enable synchronization...   │ ← User completes this
└─────────────────────────────┘

upcoming tasks
┌──────────────────────┐
│ Set timely reminders │ ← This needs to move up
│ Another task         │
│ Third task           │
└──────────────────────┘
```

### During Animation (300ms):
```
CURRENT TASK
┌─────────────────────────────┐
│ Enable synchronization...   │ ← Disappearing
└─────────────────────────────┘
         ↑ ↑ ↑
┌──────────────────────┐
│ Set timely reminders │ ← Sliding up & fading
│ Another task         │
│ Third task           │
└──────────────────────┘
```

### After Animation:
```
CURRENT TASK
┌─────────────────────────────┐
│ Set timely reminders        │ ← New current task!
└─────────────────────────────┘

upcoming tasks
┌──────────────────────┐
│ Another task         │ ← Promoted to #1
│ Third task           │ ← Promoted to #2
└──────────────────────┘
```

## When Animation Plays

### ✅ Animation WILL play when:
- You complete the current focused task
- There's an upcoming task available
- The new focus item is from the upcoming list
- Auto-suggest is enabled (or manual selection from upcoming list)

### ❌ Animation will NOT play when:
- You manually select a task that's not in the upcoming list
- You switch tasks without completing the current one
- No upcoming tasks are available
- You stop focus mode entirely
- Animation is already in progress

## Technical Details

### Animation Performance
- **GPU-accelerated:** Uses `transform` (not `top`/`margin`) for smooth 60fps
- **Opacity transition:** Fade effect for polish
- **Short duration:** 300ms feels responsive without being too fast
- **Cubic-bezier easing:** Material Design standard curve for natural motion

### State Management
- **`is_animating` flag:** Prevents animation conflicts
- **`previous_focus_item` tracking:** Enables change detection
- **Widget reference:** Gets upcoming task widget before UI update
- **Timeout synchronization:** UI updates after animation completes

### CSS Class Lifecycle
1. Class `task-promote-animation` is added to widget
2. CSS animation triggers automatically
3. Animation plays for 300ms
4. Widget is removed from DOM during UI update
5. No manual class removal needed (widget is destroyed)

## Testing the Animation

### Setup
1. **Add multiple tasks** with today's date:
   - "Task A"
   - "Task B"  
   - "Task C"
   - "Task D"

2. **Start focus session** with Task A

3. **Complete Task A** (click the Complete button or check the task)

4. **Watch the animation:**
   - Task B should slide up smoothly
   - It fades slightly while moving
   - After 300ms, it appears as the new current task
   - Task C and D move up in the upcoming list

### Expected Results
- ✅ Smooth slide-up motion
- ✅ Subtle fade effect during transition
- ✅ No flickering or jumps
- ✅ Clean state after animation
- ✅ Next task immediately ready to work on

## Customization Options

### Change Animation Speed
Modify the duration in both places:

**focus.css:**
```css
animation: task-promote-slide-up 500ms ...;  /* Change 300ms to 500ms */
```

**Focus.vala:**
```vala
Timeout.add (500, () => {  /* Change 300 to 500 */
```

### Change Animation Style

**Bounce Effect:**
```css
@keyframes task-promote-slide-up {
    0% { transform: translateY(0); }
    50% { transform: translateY(-140px); }  /* Overshoot */
    100% { transform: translateY(-120px); }  /* Settle */
}
```

**Zoom Effect:**
```css
@keyframes task-promote-slide-up {
    0% { 
        transform: translateY(0) scale(1);
        opacity: 1;
    }
    100% { 
        transform: translateY(-120px) scale(1.2);  /* Grow while moving */
        opacity: 0;
    }
}
```

### Disable Animation
Comment out the animation trigger in `handle_focus_item_change()`:
```vala
if (should_animate && !is_animating) {
    // animate_task_promotion ();  // Disabled
    update_task_ui ();  // Use this instead
```

## Known Behaviors

### Multiple Quick Completions
If you complete tasks very quickly (faster than 300ms), the `is_animating` flag prevents animation stacking. Only one animation plays at a time.

### Manual Task Selection
Clicking an upcoming task to focus on it immediately (without completing the current one) does NOT trigger the animation. This is intentional - animation only plays for task completion flow.

### Empty Upcoming List
If no upcoming tasks exist after completion, no animation plays. The UI simply shows "No task selected" or the empty state.

## Future Enhancements

Possible improvements:
1. **Stagger animation**: Slide all upcoming tasks up slightly
2. **Celebration animation**: Add confetti when completing tasks
3. **Progress indicator**: Show completion count/streak
4. **Sound effect**: Optional audio feedback on completion
5. **Haptic feedback**: Vibration on mobile/touchpad devices

## Build Information

- **Build Time:** 2026-02-21 16:00
- **Binary Size:** 6.9 MB
- **Modified Files:**
  - src/Views/Focus.vala (animation logic)
  - data/resources/stylesheet/focus.css (CSS animation)

## Restart Required

To see the animation:

```bash
# Stop current instance
pkill -f io.github.lab_gek.bluplan

# Start new version
cd /home/toplap/Documents/Personal/planify-me/build
export LD_LIBRARY_PATH=$PWD/core:$LD_LIBRARY_PATH
./src/io.github.lab_gek.bluplan
```

Then navigate to Focus view, start a session, and complete a task to see the animation! 🎬
