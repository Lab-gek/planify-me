/*
 * Copyright © 2026 Alain M. (https://github.com/alainm23/planify)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Views.Focus : Adw.Bin {
    private Layouts.HeaderBar headerbar;

    private Gtk.Label timer_label;
    private Gtk.Label state_label;
    private Gtk.Label round_label;
    private Gtk.Label current_time_label;
    private Gtk.Label end_time_label;
    private Gtk.LevelBar progress_bar;

    private Gtk.Stack task_stack;
    private Gtk.ListBox task_listbox;
    private Gtk.ListBox upcoming_listbox;

    private Gtk.Button start_pause_button;
    private Gtk.Button stop_button;
    private Gtk.Button skip_break_button;
    private Gtk.Button use_opened_task_button;
    private Gtk.Button use_suggested_task_button;

    private uint clock_timeout_id = 0;
    private Gee.HashMap<ulong, weak GLib.Object> signal_map = new Gee.HashMap<ulong, weak GLib.Object> ();
    private Objects.Item? previous_focus_item = null;
    private bool is_animating = false;
    private Gee.ArrayList<string> cached_upcoming_ids = new Gee.ArrayList<string> ();

    public Focus () {
        Object ();
    }

    ~Focus () {
        debug ("Destroying - Views.Focus\n");
    }

    construct {
        headerbar = new Layouts.HeaderBar () {
            title = _("Focus"),
            subtitle = _("Current task + Pomodoro")
        };

        timer_label = new Gtk.Label ("25:00") {
            css_classes = { "title-1", "font-bold" },
            halign = Gtk.Align.CENTER
        };
        timer_label.add_css_class ("focus-timer");

        state_label = new Gtk.Label (_("Idle")) {
            css_classes = { "caption", "dimmed" },
            halign = Gtk.Align.CENTER
        };
        state_label.add_css_class ("focus-state-label");

        round_label = new Gtk.Label (_("Round 1")) {
            css_classes = { "caption" },
            halign = Gtk.Align.CENTER
        };

        progress_bar = new Gtk.LevelBar () {
            min_value = 0,
            max_value = 1,
            value = 0,
            margin_start = 12,
            margin_end = 12
        };

        current_time_label = new Gtk.Label ("") {
            css_classes = { "caption", "dimmed" },
            halign = Gtk.Align.CENTER
        };

        end_time_label = new Gtk.Label ("") {
            css_classes = { "caption", "dimmed" },
            halign = Gtk.Align.CENTER
        };

        var timer_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) {
            margin_top = 12,
            margin_bottom = 12
        };
        timer_box.append (timer_label);
        timer_box.append (state_label);
        timer_box.append (round_label);
        timer_box.append (progress_bar);
        timer_box.append (current_time_label);
        timer_box.append (end_time_label);

        use_suggested_task_button = new Gtk.Button.with_label (_("Use Suggested Task")) {
            halign = Gtk.Align.START,
            css_classes = { "pill" }
        };

        use_opened_task_button = new Gtk.Button.with_label (_("Use Last Opened Task")) {
            halign = Gtk.Align.START,
            css_classes = { "pill" }
        };

        var empty_page = new Adw.StatusPage () {
            icon_name = "timer-symbolic",
            title = _("No task selected"),
            description = _("Open any task and select it for Focus, or let Focus suggest one.")
        };

        var empty_actions = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.CENTER,
            margin_bottom = 12
        };
        empty_actions.append (use_suggested_task_button);
        empty_actions.append (use_opened_task_button);

        var empty_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        empty_box.append (empty_page);
        empty_box.append (empty_actions);

        task_listbox = new Gtk.ListBox () {
            css_classes = { "boxed-list" },
            selection_mode = Gtk.SelectionMode.NONE,
            margin_bottom = 18
        };

        var detail_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 6,
            margin_bottom = 12
        };
        detail_box.append (new Gtk.Label (_("Current Task")) {
            css_classes = { "title-3", "font-bold" },
            xalign = 0,
            margin_bottom = 6
        });
        detail_box.append (task_listbox);

        // Add upcoming tasks section
        upcoming_listbox = new Gtk.ListBox () {
            css_classes = { "boxed-list" },
            selection_mode = Gtk.SelectionMode.NONE,
            margin_bottom = 12
        };
        // Add CSS class to make rows more compact
        upcoming_listbox.add_css_class ("compact-rows");

        var upcoming_label = new Gtk.Label (_("Upcoming Tasks")) {
            css_classes = { "caption-heading", "dim-label" },
            xalign = 0,
            margin_top = 12,
            margin_bottom = 6
        };

        detail_box.append (upcoming_label);
        detail_box.append (upcoming_listbox);

        task_stack = new Gtk.Stack () {
            transition_type = Gtk.StackTransitionType.CROSSFADE
        };
        task_stack.add_named (empty_box, "empty");
        task_stack.add_named (detail_box, "detail");

        start_pause_button = new Gtk.Button.with_label (_("Start")) {
            css_classes = { "suggested-action" }
        };

        stop_button = new Gtk.Button.with_label (_("Stop"));
        skip_break_button = new Gtk.Button.with_label (_("Skip Break"));

        var controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.CENTER,
            margin_top = 3,
            margin_bottom = 12
        };
        controls_box.append (start_pause_button);
        controls_box.append (stop_button);
        controls_box.append (skip_break_button);

        var content = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            hexpand = true,
            vexpand = true
        };
        content.append (timer_box);
        content.append (controls_box);
        content.append (task_stack);

        var content_clamp = new Adw.Clamp () {
            maximum_size = 880,
            tightening_threshold = 600,
            margin_bottom = 48,
            child = content
        };

        var scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            vexpand = true,
            child = content_clamp
        };

        var toolbar_view = new Adw.ToolbarView () {
            content = scrolled_window
        };
        toolbar_view.add_top_bar (headerbar);

        child = toolbar_view;

        signal_map[start_pause_button.clicked.connect (() => {
            var manager = Services.FocusManager.get_default ();
            if (manager.state == FocusState.IDLE) {
                manager.start ();
            } else if (manager.running) {
                manager.pause ();
            } else {
                manager.resume ();
            }
            update_timer_ui ();
            update_control_buttons ();
        })] = start_pause_button;

        signal_map[stop_button.clicked.connect (() => {
            Services.FocusManager.get_default ().stop ();
            update_timer_ui ();
            update_control_buttons ();
        })] = stop_button;

        signal_map[skip_break_button.clicked.connect (() => {
            Services.FocusManager.get_default ().skip_break ();
            update_timer_ui ();
            update_control_buttons ();
        })] = skip_break_button;

        signal_map[use_suggested_task_button.clicked.connect (() => {
            Services.FocusManager.get_default ().change_focus_item (Services.FocusManager.get_default ().suggest_focus_item ());
            update_task_ui ();
        })] = use_suggested_task_button;

        signal_map[use_opened_task_button.clicked.connect (() => {
            Services.FocusManager.get_default ().use_last_opened_item ();
            update_task_ui ();
        })] = use_opened_task_button;

        signal_map[Services.FocusManager.get_default ().timer_tick.connect (() => {
            update_timer_ui ();
            update_control_buttons ();
        })] = Services.FocusManager.get_default ();

        signal_map[Services.FocusManager.get_default ().state_changed.connect (() => {
            update_timer_ui ();
            update_control_buttons ();
        })] = Services.FocusManager.get_default ();

        signal_map[Services.FocusManager.get_default ().focus_item_changed.connect (() => {
            handle_focus_item_change ();
        })] = Services.FocusManager.get_default ();

        clock_timeout_id = Timeout.add_seconds (1, () => {
            update_timer_ui ();
            return GLib.Source.CONTINUE;
        });

        Services.FocusManager.get_default ().auto_suggest_if_enabled ();
        update_task_ui ();
        update_timer_ui ();
        update_control_buttons ();
    }



    private void handle_focus_item_change () {
        var new_item = Services.FocusManager.get_default ().focus_item;
        
        // Check if new task was in the cached upcoming list
        bool should_animate = false;
        if (previous_focus_item != null && new_item != null) {
            // Check if the new item was in our cached upcoming list
            should_animate = cached_upcoming_ids.contains (new_item.id);
        }
        
        previous_focus_item = new_item;
        
        if (should_animate && !is_animating) {
            animate_task_promotion ();
        } else {
            update_task_ui ();
            update_control_buttons ();
        }
    }

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

    private void update_task_ui () {
        var item = Services.FocusManager.get_default ().focus_item;
        if (item == null) {
            task_stack.visible_child_name = "empty";
            return;
        }

        task_stack.visible_child_name = "detail";
        
        var child = task_listbox.get_first_child ();
        if (child != null) {
            task_listbox.remove (child);
        }

        var row = new Layouts.ItemRow (item);
        row.edit = true;
        task_listbox.append (row);

        // Update upcoming tasks list
        update_upcoming_tasks ();
    }

    private void update_upcoming_tasks () {
        // Clear existing upcoming tasks
        Gtk.Widget? child = upcoming_listbox.get_first_child ();
        while (child != null) {
            upcoming_listbox.remove (child);
            child = upcoming_listbox.get_first_child ();
        }

        // Get and display upcoming tasks
        var upcoming_items = Services.FocusManager.get_default ().get_suggested_focus_items (5);
        
        // Cache the IDs for animation detection
        cached_upcoming_ids.clear ();
        foreach (var item in upcoming_items) {
            cached_upcoming_ids.add (item.id);
        }
        
        if (upcoming_items.size == 0) {
            var no_tasks_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                height_request = 48,
                valign = Gtk.Align.CENTER
            };
            var no_tasks_label = new Gtk.Label (_("No upcoming tasks")) {
                css_classes = { "dim-label", "caption" },
                margin_top = 12,
                margin_bottom = 12
            };
            no_tasks_box.append (no_tasks_label);
            upcoming_listbox.append (no_tasks_box);
        } else {
            foreach (var upcoming_item in upcoming_items) {
                var row = new Layouts.ItemRow (upcoming_item);
                row.edit = false;
                // Add CSS class for compact display
                row.add_css_class ("compact-task-row");
                
                // Make it clickable to set as focus item
                var gesture = new Gtk.GestureClick ();
                gesture.released.connect (() => {
                    Services.FocusManager.get_default ().change_focus_item (upcoming_item);
                });
                row.add_controller (gesture);
                
                upcoming_listbox.append (row);
            }
        }
    }

    private void update_timer_ui () {
        var manager = Services.FocusManager.get_default ();
        int remaining = manager.seconds_remaining;

        if (manager.state == FocusState.IDLE && remaining <= 0) {
            remaining = Services.Settings.get_default ().settings.get_int ("focus-work-duration") * 60;
        }

        timer_label.label = format_seconds (remaining);
        state_label.label = manager.get_state_label ();
        round_label.label = _("Round %d").printf (manager.current_round);

        if (manager.state == FocusState.SHORT_BREAK || manager.state == FocusState.LONG_BREAK) {
            timer_label.add_css_class ("focus-timer-break");
            state_label.add_css_class ("focus-state-break");
        } else {
            timer_label.remove_css_class ("focus-timer-break");
            state_label.remove_css_class ("focus-state-break");
        }

        progress_bar.value = manager.get_progress ();
        progress_bar.remove_offset_value ("break-point");
        if (manager.state != FocusState.IDLE) {
            progress_bar.add_offset_value ("break-point", manager.get_break_point ());
        }

        var now = new GLib.DateTime.now_local ();
        current_time_label.label = _("Current time: %s").printf (now.format (Utils.Datetime.get_default_time_format (Utils.Datetime.is_clock_format_12h (), true)));

        if (remaining > 0) {
            var end_time = now.add_seconds (remaining);
            end_time_label.label = _("Ends at: %s").printf (end_time.format (Utils.Datetime.get_default_time_format ()));
        } else {
            end_time_label.label = "";
        }
    }

    private void update_control_buttons () {
        var manager = Services.FocusManager.get_default ();

        if (manager.state == FocusState.IDLE) {
            start_pause_button.label = _("Start");
        } else {
            start_pause_button.label = manager.running ? _("Pause") : _("Resume");
        }

        stop_button.sensitive = manager.state != FocusState.IDLE;
        skip_break_button.sensitive = manager.state == FocusState.SHORT_BREAK || manager.state == FocusState.LONG_BREAK;

    }

    private string format_seconds (int total_seconds) {
        int minutes = total_seconds / 60;
        int seconds = total_seconds % 60;
        return "%02d:%02d".printf (minutes, seconds);
    }

    public void clean_up () {
        if (clock_timeout_id != 0) {
            GLib.Source.remove (clock_timeout_id);
            clock_timeout_id = 0;
        }

        foreach (var entry in signal_map.entries) {
            entry.value.disconnect (entry.key);
        }

        signal_map.clear ();
        headerbar.clean_up ();
    }
}