/*
 * Copyright © 2026 Alain M. (https://github.com/alainm23/planify)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Services.FocusManager : GLib.Object {
    private static FocusManager ? _instance;
    public static FocusManager get_default () {
        if (_instance == null) {
            _instance = new FocusManager ();
        }

        return _instance;
    }

    public signal void focus_item_changed ();
    public signal void state_changed ();
    public signal void timer_tick ();

    private uint timer_timeout_id = 0;
    private int interval_duration_seconds = 0;

    public FocusState state { get; private set; default = FocusState.IDLE; }
    public bool running { get; private set; default = false; }
    public int seconds_remaining { get; private set; default = 0; }
    public int current_round { get; private set; default = 1; }
    public int total_break_seconds { get; private set; default = 0; }
    public Objects.Item ? focus_item { get; private set; default = null; }
    public Objects.Item ? last_opened_item { get; private set; default = null; }

    construct {
        restore_focus_item ();
        restore_session_state ();

        signal_map[Services.EventBus.get_default ().open_item.connect ((item) => {
            last_opened_item = item;
        })] = Services.EventBus.get_default ();

        signal_map[Services.Store.instance ().item_deleted.connect ((item) => {
            clear_focus_item_if_matches (item.id);
        })] = Services.Store.instance ();

        signal_map[Services.Store.instance ().item_archived.connect ((item) => {
            clear_focus_item_if_matches (item.id);
        })] = Services.Store.instance ();

        signal_map[Services.Store.instance ().item_updated.connect ((item, update_id) => {
            if (item.checked) {
                clear_focus_item_if_matches (item.id);
            }
        })] = Services.Store.instance ();

        signal_map[Services.EventBus.get_default ().checked_toggled.connect ((item, old_checked) => {
            if (!old_checked && focus_item != null && focus_item.id == item.id) {
                change_focus_item (null);
                auto_suggest_if_enabled ();
                if (focus_item == null) {
                    stop ();
                }
            }
        })] = Services.EventBus.get_default ();
    }

    private Gee.HashMap<ulong, weak GLib.Object> signal_map = new Gee.HashMap<ulong, weak GLib.Object> ();

    private void clear_focus_item_if_matches (string item_id) {
        if (focus_item != null && focus_item.id == item_id) {
            stop ();
            change_focus_item (null);
        }
    }

    private int get_work_duration_seconds () {
        return Services.Settings.get_default ().settings.get_int ("focus-work-duration") * 60;
    }

    private int get_short_break_duration_seconds () {
        return Services.Settings.get_default ().settings.get_int ("focus-short-break") * 60;
    }

    private int get_long_break_duration_seconds () {
        return Services.Settings.get_default ().settings.get_int ("focus-long-break") * 60;
    }

    private int get_rounds_before_long_break () {
        int rounds_before_long = Services.Settings.get_default ().settings.get_int ("focus-rounds-before-long-break");
        if (rounds_before_long <= 0) {
            rounds_before_long = 4;
        }

        return rounds_before_long;
    }

    public void change_focus_item (Objects.Item ? item) {
        focus_item = item;

        if (item == null) {
            Services.Settings.get_default ().settings.set_string ("focus-current-item-id", "");
        } else {
            Services.Settings.get_default ().settings.set_string ("focus-current-item-id", item.id);
        }

        Objects.Filters.Focus.get_default ().count_update ();
        focus_item_changed ();
    }

    private void sync_session_settings () {
        var settings = Services.Settings.get_default ().settings;
        bool active = state != FocusState.IDLE;
        settings.set_boolean ("focus-session-active", active);
        settings.set_int ("focus-break-seconds", total_break_seconds);

        if (!active) {
            settings.set_int ("focus-session-state", (int) FocusState.IDLE);
            settings.set_boolean ("focus-session-running", false);
            settings.set_int ("focus-session-seconds-remaining", 0);
            settings.set_int ("focus-session-interval-duration", 0);
            settings.set_int ("focus-session-current-round", 1);
            settings.set_int64 ("focus-session-last-updated-unix", 0);
            return;
        }

        settings.set_int ("focus-session-state", (int) state);
        settings.set_boolean ("focus-session-running", running);
        settings.set_int ("focus-session-seconds-remaining", seconds_remaining);
        settings.set_int ("focus-session-interval-duration", interval_duration_seconds);
        settings.set_int ("focus-session-current-round", current_round);
        settings.set_int64 ("focus-session-last-updated-unix", new GLib.DateTime.now_utc ().to_unix ());
    }

    public void use_last_opened_item () {
        if (last_opened_item != null) {
            change_focus_item (last_opened_item);
        }
    }

    public Objects.Item ? suggest_focus_item () {
        var now = new GLib.DateTime.now_local ();

        foreach (var item in Services.Store.instance ().get_items_by_scheduled (false)) {
            if (item == null || item.checked || item.due == null || item.due.datetime == null) {
                continue;
            }

            var start_dt = item.due.datetime;
            var end_dt = item.due.has_end_date ? Utils.Datetime.get_todoist_datetime (item.due.end_date) : null;

            if (end_dt != null) {
                if (start_dt.compare (now) <= 0 && end_dt.compare (now) >= 0) {
                    return item;
                }
            } else if (Utils.Datetime.is_today (start_dt)) {
                return item;
            }
        }

        var today_items = Services.Store.instance ().get_items_by_date (now, false);
        if (today_items.size > 0) {
            return today_items[0];
        }

        return null;
    }

    public void auto_suggest_if_enabled () {
        if (!Services.Settings.get_default ().settings.get_boolean ("focus-auto-suggest")) {
            return;
        }

        if (focus_item != null) {
            return;
        }

        change_focus_item (suggest_focus_item ());
    }

    public void start () {
        if (focus_item == null) {
            auto_suggest_if_enabled ();
        }

        if (focus_item == null) {
            return;
        }

        if (state == FocusState.IDLE) {
            current_round = 1;
            total_break_seconds = 0;
            sync_session_settings ();
            begin_work_interval ();
            return;
        }

        resume ();
    }

    public void pause () {
        running = false;
        stop_timeout ();
        sync_session_settings ();
        state_changed ();
    }

    public void resume () {
        if (state == FocusState.IDLE || seconds_remaining <= 0) {
            return;
        }

        running = true;
        ensure_timeout_running ();
        sync_session_settings ();
        state_changed ();
    }

    public void stop () {
        stop_timeout ();
        running = false;
        state = FocusState.IDLE;
        seconds_remaining = 0;
        interval_duration_seconds = 0;
        total_break_seconds = 0;
        current_round = 1;
        sync_session_settings ();

        Objects.Filters.Focus.get_default ().count_update ();
        state_changed ();
        timer_tick ();
    }

    public void skip_break () {
        if (state != FocusState.SHORT_BREAK && state != FocusState.LONG_BREAK) {
            return;
        }

        finish_break_interval (false);
    }

    public double get_progress () {
        if (interval_duration_seconds <= 0) {
            return 0;
        }

        var w_dur = Services.Settings.get_default ().settings.get_int ("focus-work-duration") * 60;
        int rounds_before_long = Services.Settings.get_default ().settings.get_int ("focus-rounds-before-long-break");
        bool next_is_long = (current_round >= rounds_before_long);
        var b_dur = Services.Settings.get_default ().settings.get_int (next_is_long ? "focus-long-break" : "focus-short-break") * 60;
        double total = w_dur + b_dur;

        if (state == FocusState.WORKING) {
            return (double) (w_dur - seconds_remaining) / total;
        } else if (state == FocusState.SHORT_BREAK || state == FocusState.LONG_BREAK) {
            return (double) (w_dur + b_dur - seconds_remaining) / total;
        }

        return 0;
    }

    public double get_break_point () {
        var w_dur = Services.Settings.get_default ().settings.get_int ("focus-work-duration") * 60;
        int rounds_before_long = Services.Settings.get_default ().settings.get_int ("focus-rounds-before-long-break");
        bool next_is_long = (current_round >= rounds_before_long);
        var b_dur = Services.Settings.get_default ().settings.get_int (next_is_long ? "focus-long-break" : "focus-short-break") * 60;

        return (double) w_dur / (w_dur + b_dur);
    }

    public string get_state_label () {
        switch (state) {
            case FocusState.WORKING:
                return _("Working");
            case FocusState.SHORT_BREAK:
                return _("Short Break");
            case FocusState.LONG_BREAK:
                return _("Long Break");
            default:
                return _("Idle");
        }
    }

    private void begin_work_interval () {
        state = FocusState.WORKING;
        interval_duration_seconds = get_work_duration_seconds ();
        seconds_remaining = interval_duration_seconds;
        running = true;
        sync_session_settings ();
        Objects.Filters.Focus.get_default ().count_update ();
        state_changed ();
        timer_tick ();
        ensure_timeout_running ();
    }

    private void begin_short_break_interval () {
        state = FocusState.SHORT_BREAK;
        interval_duration_seconds = get_short_break_duration_seconds ();
        seconds_remaining = interval_duration_seconds;
        running = true;
        sync_session_settings ();
        state_changed ();
        timer_tick ();
        ensure_timeout_running ();
    }

    private void begin_long_break_interval () {
        state = FocusState.LONG_BREAK;
        interval_duration_seconds = get_long_break_duration_seconds ();
        seconds_remaining = interval_duration_seconds;
        running = true;
        sync_session_settings ();
        state_changed ();
        timer_tick ();
        ensure_timeout_running ();
    }

    private void finish_work_interval () {
        int rounds_before_long = get_rounds_before_long_break ();

        send_work_completed_notification ();

        if (current_round >= rounds_before_long) {
            begin_long_break_interval ();
        } else {
            begin_short_break_interval ();
        }
    }

    private void finish_break_interval (bool notify = true) {
        if (notify) {
            send_break_completed_notification ();
        }

        if (state == FocusState.LONG_BREAK) {
            current_round = 1;
        } else {
            current_round++;
        }

        begin_work_interval ();
    }

    private bool on_timeout_tick () {
        if (!running) {
            return GLib.Source.REMOVE;
        }

        if (seconds_remaining > 0) {
            seconds_remaining--;

            if (state == FocusState.SHORT_BREAK || state == FocusState.LONG_BREAK) {
                total_break_seconds++;
            }

            sync_session_settings ();
            timer_tick ();
        }

        if (seconds_remaining <= 0) {
            if (state == FocusState.WORKING) {
                finish_work_interval ();
            } else if (state == FocusState.SHORT_BREAK || state == FocusState.LONG_BREAK) {
                finish_break_interval ();
            }
        }

        return GLib.Source.CONTINUE;
    }

    private void ensure_timeout_running () {
        if (timer_timeout_id != 0) {
            return;
        }

        timer_timeout_id = Timeout.add_seconds (1, () => {
            bool keep = on_timeout_tick ();
            if (!keep) {
                timer_timeout_id = 0;
            }

            return keep;
        });
    }

    private void stop_timeout () {
        if (timer_timeout_id != 0) {
            GLib.Source.remove (timer_timeout_id);
            timer_timeout_id = 0;
        }
    }

    private void restore_focus_item () {
        var settings = Services.Settings.get_default ().settings;
        var id = Services.Settings.get_default ().settings.get_string ("focus-current-item-id");
        if (id == null || id == "") {
            return;
        }

        var item = Services.Store.instance ().get_item (id);
        if (item != null && !item.checked) {
            focus_item = item;
            return;
        }

        settings.set_string ("focus-current-item-id", "");
        Objects.Filters.Focus.get_default ().count_update ();
    }

    private void restore_session_state () {
        var settings = Services.Settings.get_default ().settings;

        if (!settings.get_boolean ("focus-session-active")) {
            return;
        }

        if (focus_item == null) {
            stop ();
            return;
        }

        int persisted_state = settings.get_int ("focus-session-state");
        if (persisted_state < (int) FocusState.IDLE || persisted_state > (int) FocusState.LONG_BREAK) {
            stop ();
            return;
        }

        state = (FocusState) persisted_state;
        running = settings.get_boolean ("focus-session-running");
        seconds_remaining = int.max (0, settings.get_int ("focus-session-seconds-remaining"));
        interval_duration_seconds = int.max (0, settings.get_int ("focus-session-interval-duration"));
        current_round = int.max (1, settings.get_int ("focus-session-current-round"));
        total_break_seconds = int.max (0, settings.get_int ("focus-break-seconds"));

        if (interval_duration_seconds <= 0) {
            if (state == FocusState.WORKING) {
                interval_duration_seconds = get_work_duration_seconds ();
            } else if (state == FocusState.SHORT_BREAK) {
                interval_duration_seconds = get_short_break_duration_seconds ();
            } else if (state == FocusState.LONG_BREAK) {
                interval_duration_seconds = get_long_break_duration_seconds ();
            }

            if (seconds_remaining <= 0) {
                seconds_remaining = interval_duration_seconds;
            }
        }

        if (running) {
            int64 now_unix = new GLib.DateTime.now_utc ().to_unix ();
            int64 last_updated_unix = settings.get_int64 ("focus-session-last-updated-unix");
            int elapsed = 0;

            if (last_updated_unix > 0 && now_unix > last_updated_unix) {
                elapsed = (int) (now_unix - last_updated_unix);
            }

            if (elapsed > 0) {
                advance_elapsed_seconds (elapsed);
            }
        }

        if (state != FocusState.IDLE && running) {
            ensure_timeout_running ();
        }

        sync_session_settings ();
        state_changed ();
        timer_tick ();
    }

    private void advance_elapsed_seconds (int elapsed_seconds) {
        int remaining_elapsed = elapsed_seconds;

        while (remaining_elapsed > 0 && state != FocusState.IDLE) {
            if (seconds_remaining <= 0) {
                advance_state_after_elapsed_interval ();
                continue;
            }

            if (remaining_elapsed < seconds_remaining) {
                if (state == FocusState.SHORT_BREAK || state == FocusState.LONG_BREAK) {
                    total_break_seconds += remaining_elapsed;
                }

                seconds_remaining -= remaining_elapsed;
                remaining_elapsed = 0;
                continue;
            }

            if (state == FocusState.SHORT_BREAK || state == FocusState.LONG_BREAK) {
                total_break_seconds += seconds_remaining;
            }

            remaining_elapsed -= seconds_remaining;
            seconds_remaining = 0;
            advance_state_after_elapsed_interval ();
        }
    }

    private void advance_state_after_elapsed_interval () {
        if (state == FocusState.WORKING) {
            int rounds_before_long = get_rounds_before_long_break ();

            if (current_round >= rounds_before_long) {
                state = FocusState.LONG_BREAK;
                interval_duration_seconds = get_long_break_duration_seconds ();
            } else {
                state = FocusState.SHORT_BREAK;
                interval_duration_seconds = get_short_break_duration_seconds ();
            }

            seconds_remaining = interval_duration_seconds;
            return;
        }

        if (state == FocusState.SHORT_BREAK || state == FocusState.LONG_BREAK) {
            if (state == FocusState.LONG_BREAK) {
                current_round = 1;
            } else {
                current_round++;
            }

            state = FocusState.WORKING;
            interval_duration_seconds = get_work_duration_seconds ();
            seconds_remaining = interval_duration_seconds;
            return;
        }

        running = false;
        state = FocusState.IDLE;
        seconds_remaining = 0;
        interval_duration_seconds = 0;
    }

    private void send_work_completed_notification () {
        string title = _("Focus: Work interval complete");
        string body;

        if (focus_item != null && focus_item.content != null && focus_item.content != "") {
            body = _("Time for a break. Task: %s").printf (focus_item.content);
        } else {
            body = _("Time for a break.");
        }

        send_focus_notification (title, body);
    }

    private void send_break_completed_notification () {
        string title = _("Focus: Break ended");
        string body;

        if (focus_item != null && focus_item.content != null && focus_item.content != "") {
            body = _("Back to work. Continue: %s").printf (focus_item.content);
        } else {
            body = _("Back to work.");
        }

        send_focus_notification (title, body);
    }

    private void send_focus_notification (string title, string body) {
        var notification = new GLib.Notification (title);
        notification.set_body (body);
        notification.set_icon (new ThemedIcon ("io.github.lab_gek.bluplan"));
        notification.set_priority (GLib.NotificationPriority.NORMAL);

        string id = "focus-%u".printf (GLib.Random.next_int ());
        BluPlan.instance.send_notification (id, notification);
    }
}