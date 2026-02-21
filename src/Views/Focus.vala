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

    private Gtk.Button start_pause_button;
    private Gtk.Button stop_button;
    private Gtk.Button skip_break_button;
    private Gtk.Button use_opened_task_button;
    private Gtk.Button use_suggested_task_button;

    private uint clock_timeout_id = 0;
    private Gee.HashMap<ulong, weak GLib.Object> signal_map = new Gee.HashMap<ulong, weak GLib.Object> ();

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
            margin_bottom = 12
        };

        var detail_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 6,
            margin_bottom = 12
        };
        detail_box.append (new Gtk.Label (_("Current Task")) {
            css_classes = { "font-bold" },
            xalign = 0
        });
        detail_box.append (task_listbox);

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
            update_task_ui ();
            update_control_buttons ();
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