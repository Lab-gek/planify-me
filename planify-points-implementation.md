Summary of implementation:

1. **Schema & Settings**: Added `points-enabled`, `points-grace-period`, and `points-assume-working` to `gschema.xml`.
2. **Database Integration**:
   - Added `points` column to `Items` table in `Database.vala`.
   - Updated `create_tables`, `patch_database`, `insert_item`, `update_item`, `_fill_item`.
   - `calculate_points()` is called before `update_item` and `complete_item` to ensure correct point value is stored.

3. **Core Logic (Item.vala)**:
   - Added `points` property to `Item`.
   - Implemented `calculate_points()`:
     - Calculates scheduled minutes from `DueDate`.
     - Base points: `floor(duration / 5)`. Max 24.
     - Early bonus: +1 if completed >= 5 mins early.
     - Late penalty: 
       - If assume_working off, check against due + grace.
       - Logic updated to match user example (0-10 min late -> 50% points).

4. **Project Aggregation (Project.vala)**:
   - Added `points` property to `Project`.
   - Recursively sums points from direct items and sub-projects.

5. **UI Updates**:
   - **Project Row**: Updated `ProjectRow.vala` to display points next to item count.
   - **Header Bar**: Updated `HeaderBar.vala` to display total user points (sum of all completed items) in the title bar area, centered.

Note: The implementation assumes standard Vala/GLib definitions. Time unit conversion uses `GLib.TimeSpan.MINUTE`.
