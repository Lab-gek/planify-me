# BluPlan Focus Extension - Visual Guide

## Display Examples

### Top Bar Display

#### Compact Mode
```
┌────────────────────────────────────────────────────────────┐
│ Activities  ...  [⏰]  ...  System Icons    ▼              │
└────────────────────────────────────────────────────────────┘
```
- Minimal footprint
- Icon only (changes based on state)
- Perfect for small screens

#### Expanded Mode (Default)
```
┌────────────────────────────────────────────────────────────┐
│ Activities  ...  [⏰ 23:45]  ...  System Icons    ▼        │
└────────────────────────────────────────────────────────────┘
```
- Timer display
- Icon indicates state
- Balanced information

#### Expanded with Task Name
```
┌──────────────────────────────────────────────────────────────────────┐
│ Activities  ...  [⏰ 23:45 Write documentation]  ...  Icons    ▼     │
└──────────────────────────────────────────────────────────────────────┘
```
- Full context at a glance
- Task name truncated if too long
- Maximum information density

### Icon States

```
⏰  Working (timer running)
⏸️  Paused / Idle
✓  On Break (short or long)
```

### Popup Menu

#### Full Menu (All Options Enabled)
```
┌───────────────────────────────────────────────┐
│ Working: Write documentation                  │  ← Current Task (clickable)
├───────────────────────────────────────────────┤
│  [▶️]    [⏹️]    [✓]                           │  ← Control Buttons
├───────────────────────────────────────────────┤
│ Next Task                                     │
│ Review pull requests                          │  ← Next Suggested (clickable)
├───────────────────────────────────────────────┤
│ Connected to BluPlan                          │  ← Status
└───────────────────────────────────────────────┘
```

#### Minimal Menu (Controls Only)
```
┌───────────────────────────────────────────────┐
│ Idle: No task selected                        │
├───────────────────────────────────────────────┤
│  [▶️]    [⏹️]    [✓]                           │
├───────────────────────────────────────────────┤
│ Connected to BluPlan                          │
└───────────────────────────────────────────────┘
```

#### With Next Task Preview
```
┌───────────────────────────────────────────────┐
│ Working: Fix bug #123                         │
├───────────────────────────────────────────────┤
│  [⏸️]    [⏹️]    [✓]                           │
├───────────────────────────────────────────────┤
│ Next Task                                     │
│ Deploy to production                          │
├───────────────────────────────────────────────┤
│ Connected to BluPlan                          │
└───────────────────────────────────────────────┘
```

#### Disconnected State
```
┌───────────────────────────────────────────────┐
│ No task selected                              │
├───────────────────────────────────────────────┤
│  [▶️]    [⏹️]    [✓]                           │
├───────────────────────────────────────────────┤
│ BluPlan not running                           │  ← Auto-launches on click
└───────────────────────────────────────────────┘
```

## Preferences Window

```
╔════════════════════════════════════════════════════════════╗
║ BluPlan Focus - Preferences                            × ║
╠════════════════════════════════════════════════════════════╣
║                                                             ║
║  Display Mode                                              ║
║  ─────────────────────────────────────────────────────────  ║
║  Control how the extension appears in the top bar         ║
║                                                             ║
║  View Mode                                                 ║
║  Choose how much information to display                   ║
║  [Expanded (icon + timer + task)      ▼]                  ║
║                                                             ║
║                                                             ║
║  Element Visibility                                        ║
║  ─────────────────────────────────────────────────────────  ║
║  Choose which elements to display (Custom mode)           ║
║                                                             ║
║  Show Timer                                    [ON  ]      ║
║  Display countdown timer in the panel                     ║
║                                                             ║
║  Show Task Name                                [ON  ]      ║
║  Display the currently focused task name                  ║
║                                                             ║
║  Show Controls                                 [ON  ]      ║
║  Display control buttons in the popup menu                ║
║                                                             ║
║  Show Next Task                                [ON  ]      ║
║  Display next scheduled task in the menu                  ║
║                                                             ║
║                                                             ║
║  Button Position                                           ║
║  ─────────────────────────────────────────────────────────  ║
║  Choose where the button appears in the top bar           ║
║                                                             ║
║  Panel Position                                            ║
║  Location of the button in the top bar                    ║
║  [Right                               ▼]                   ║
║                                                             ║
║                                                             ║
║  About                                                     ║
║  ─────────────────────────────────────────────────────────  ║
║  BluPlan Focus Extension                                   ║
║  Display BluPlan Pomodoro timer in GNOME Shell top bar    ║
║                                                             ║
║  BluPlan Project                             [GitHub →]    ║
║                                                             ║
╚════════════════════════════════════════════════════════════╝
```

## User Interactions

### Starting a Focus Session

**Method 1: From Extension (Auto-suggest)**
```
1. Click extension icon in top bar
   ┌─────────────────────────┐
   │ Idle                    │
   │  [▶️]  [⏹️]  [✓]        │
   └─────────────────────────┘

2. Click ▶️ button
   
3. Extension starts focus with auto-suggested task
   [⏰ 25:00 Review code]
```

**Method 2: From Next Task**
```
1. Click extension icon
   ┌─────────────────────────┐
   │ Next Task               │
   │ Deploy to production  ← │ Click here
   └─────────────────────────┘

2. Starts focus with that specific task
   [⏰ 25:00 Deploy to pro...]
```

**Method 3: From BluPlan App**
```
1. Select task in BluPlan
2. Click "Focus" button in app
3. Extension automatically syncs
   [⏰ 25:00 Task name]
```

### During a Focus Session

```
[⏰ 24:32 Write tests]  ← Timer counts down every second

Click to open menu:
┌─────────────────────────┐
│ Working: Write tests    │
│  [⏸️]  [⏹️]  [✓]        │  ← Pause, Stop, or Complete
└─────────────────────────┘
```

### Pausing

```
Before:  [⏰ 15:23 Task name]
         Click ⏸️

After:   [⏸️ 15:23 Task name]  ← Icon changes, timer frozen
         Click ▶️ to resume
```

### Completing Task

```
[⏰ 12:45 Task name]
Click ✓ button

→ Task marked complete in BluPlan
→ Extension shows next suggestion or goes idle
```

### Break Time

```
Work Interval Ends:
[⏰ 00:00 Task name]  →  [✓ 05:00 Short Break]

Timer automatically switches to break
Icon changes to ✓ (checkmark)
Timer shows break countdown
```

### State Flow Visualization

```
┌──────┐  Click ▶️   ┌─────────┐  Timer    ┌───────────┐
│ IDLE │ ────────→   │ WORKING │  Expires  │   BREAK   │
└──────┘             └─────────┘  ────→    └───────────┘
   ↑                     │  ↑                    │
   │    Click ⏹️         │  │  Click ▶️/⏸️       │  Timer
   └─────────────────────┘  └───────────────────┘  Expires
                           (Pause/Resume)              ↓
                                                   ┌─────────┐
                                                   │ WORKING │
                                            (Next)└─────────┘
```

## Configuration Examples

### Scenario: Minimalist Setup

**Need:** Maximum screen space, minimal distraction

**Configuration:**
- View Mode: Compact
- Show Controls: Yes
- Show Next Task: No

**Result:**
```
Top Bar: [⏰]
Menu:    Current task + controls only
```

### Scenario: Maximum Information

**Need:** See everything at a glance, large monitor

**Configuration:**
- View Mode: Expanded
- Show Task Name: Yes
- Show Controls: Yes
- Show Next Task: Yes

**Result:**
```
Top Bar: [⏰ 23:45 Current Task Name]
Menu:    Full display with all features
```

### Scenario: On-Demand Information

**Need:** Clean top bar, detailed menu

**Configuration:**
- View Mode: Compact
- Show Controls: Yes
- Show Next Task: Yes

**Result:**
```
Top Bar: [⏰]
Menu:    Full menu with controls and next task
```

### Scenario: Timer-Only Focus

**Need:** Just see the countdown, nothing else

**Configuration:**
- View Mode: Custom
- Show Timer: Yes
- Show Task Name: No
- Show Controls: No
- Show Next Task: No

**Result:**
```
Top Bar: [⏰ 23:45]
Menu:    Task name + status only (minimal)
```

## Position Examples

### Left Position
```
┌────────────────────────────────────────────────┐
│ [⏰ 25:00] Activities  Calendar  ...           │
└────────────────────────────────────────────────┘
```

### Center Position
```
┌────────────────────────────────────────────────┐
│ Activities  ...  [⏰ 25:00]  ...  Icons    ▼   │
└────────────────────────────────────────────────┘
```

### Right Position (Default)
```
┌────────────────────────────────────────────────┐
│ Activities  ...  System Icons  [⏰ 25:00]  ▼   │
└────────────────────────────────────────────────┘
```

## Typical Workflows

### Morning Planning
```
1. Start work day
2. Extension shows: [⏸️] (idle)
3. Click extension → See next task preview
4. Click next task to start focus session
5. Work begins: [⏰ 25:00 Plan sprint]
```

### Task Completion
```
1. During focus: [⏰ 03:21 Fix bug]
2. Finish task early
3. Click ✓ button in menu
4. Task marked complete
5. Extension suggests next: "Review PR"
6. Continue or take break
```

### Break Time
```
1. Work interval ends: [⏰ 00:00]
2. Auto-transitions: [✓ 05:00 Short Break]
3. Take break
4. Break ends: [⏰ 25:00 Next Task]
5. Continue working
```

### End of Day
```
1. Active session: [⏰ 12:34 Last task]
2. Need to leave
3. Click ⏹️ (Stop)
4. Session ends: [⏸️] (idle)
5. Progress saved in BluPlan
```

## Visual Feedback Summary

| State | Icon | Timer | Behavior |
|-------|------|-------|----------|
| Idle | ⏸️ | --:-- | No active session |
| Working | ⏰ | Counting down | Red/Active indicator |
| Paused | ⏸️ | Frozen time | Static display |
| Short Break | ✓ | Counting down | Green/Success indicator |
| Long Break | ✓ | Counting down | Green/Success indicator |
| Disconnected | ⏸️ | --:-- or last known | Grayed out controls |

---

This visual guide provides a comprehensive understanding of how the extension appears and behaves in different scenarios and configurations.
