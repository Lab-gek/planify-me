/*
 * Copyright © 2026 Alain M. (https://github.com/alainm23/planify)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Services.FocusQueueProposal : GLib.Object {
    public Objects.Item item { get; construct; }
    public GLib.DateTime proposed_start { get; construct; }
    public GLib.DateTime proposed_end { get; construct; }
    public int duration_seconds { get; construct; }
    public int starting_round { get; construct; }
    public int starting_work_progress_seconds { get; construct; }
    public bool has_conflict { get; construct; }
    public bool rolls_to_tomorrow { get; construct; }
    public bool uses_existing_duration { get; construct; }

    public FocusQueueProposal (Objects.Item item, GLib.DateTime proposed_start, GLib.DateTime proposed_end,
                               int duration_seconds, int starting_round, int starting_work_progress_seconds,
                               bool has_conflict,
                               bool rolls_to_tomorrow, bool uses_existing_duration) {
        Object (
            item: item,
            proposed_start: proposed_start,
            proposed_end: proposed_end,
            duration_seconds: duration_seconds,
            starting_round: starting_round,
            starting_work_progress_seconds: starting_work_progress_seconds,
            has_conflict: has_conflict,
            rolls_to_tomorrow: rolls_to_tomorrow,
            uses_existing_duration: uses_existing_duration
        );
    }
}

public class Services.FocusManager : GLib.Object {
    private static FocusManager ? _instance;
    public static FocusManager get_default () {
        if (_instance == null) {
            _instance = new FocusManager ();
        }

        return _instance;
    }

    public signal void focus_item_changed ();
    public signal void queue_changed ();
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
    private Gee.ArrayList<string> queued_item_ids = new Gee.ArrayList<string> ();
    private Gee.HashMap<string, int> queued_item_durations = new Gee.HashMap<string, int> ();

    construct {
        restore_focus_item ();
        restore_queue ();
        restore_session_state ();

        signal_map[Services.EventBus.get_default ().open_item.connect ((item) => {
            last_opened_item = item;
        })] = Services.EventBus.get_default ();

        signal_map[Services.Store.instance ().item_deleted.connect ((item) => {
            clear_focus_item_if_matches (item.id);
            remove_queue_item_if_matches (item.id);
        })] = Services.Store.instance ();

        signal_map[Services.Store.instance ().item_archived.connect ((item) => {
            clear_focus_item_if_matches (item.id);
            remove_queue_item_if_matches (item.id);
        })] = Services.Store.instance ();

        signal_map[Services.Store.instance ().item_updated.connect ((item, update_id) => {
            if (item.checked) {
                clear_focus_item_if_matches (item.id);
                remove_queue_item_if_matches (item.id);
            }
        })] = Services.Store.instance ();

        signal_map[Services.EventBus.get_default ().checked_toggled.connect ((item, old_checked) => {
            if (!old_checked && focus_item != null && focus_item.id == item.id) {
                change_focus_item (null);
                promote_next_focus_item ();
                if (focus_item == null) {
                    stop ();
                }
            }
        })] = Services.EventBus.get_default ();
    }

    private Gee.HashMap<ulong, weak GLib.Object> signal_map = new Gee.HashMap<ulong, weak GLib.Object> ();

    private void clear_focus_item_if_matches (string item_id) {
        if (focus_item != null && focus_item.id == item_id) {
            change_focus_item (null);
            promote_next_focus_item ();
            if (focus_item == null) {
                stop ();
            }
        }
    }

    private void remove_queue_item_if_matches (string item_id) {
        if (queued_item_ids.contains (item_id)) {
            queued_item_ids.remove (item_id);
            queued_item_durations.unset (item_id);
            sync_queue_settings ();
            queue_changed ();
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

    private int get_queue_break_behavior () {
        return Services.Settings.get_default ().settings.get_enum ("focus-queue-break-behavior");
    }

    private bool queue_uses_pomodoro_session_breaks () {
        return get_queue_break_behavior () == 0;
    }

    private int get_between_task_break_seconds () {
        return 5 * 60;
    }

    public void change_focus_item (Objects.Item ? item) {
        focus_item = item;

        bool queue_updated = false;
        if (item != null && queued_item_ids.contains (item.id)) {
            queued_item_ids.remove (item.id);
            queued_item_durations.unset (item.id);
            sync_queue_settings ();
            queue_updated = true;
        }

        if (item == null) {
            Services.Settings.get_default ().settings.set_string ("focus-current-item-id", "");
        } else {
            Services.Settings.get_default ().settings.set_string ("focus-current-item-id", item.id);
        }

        Objects.Filters.Focus.get_default ().count_update ();
        focus_item_changed ();

        if (queue_updated) {
            queue_changed ();
        }
    }

    private string[] build_queue_id_settings_values () {
        var values = new string[queued_item_ids.size];

        for (int i = 0; i < queued_item_ids.size; i++) {
            values[i] = queued_item_ids[i];
        }

        return values;
    }

    private string[] build_queue_duration_settings_values () {
        var values = new Gee.ArrayList<string> ();

        foreach (var item_id in queued_item_ids) {
            if (!queued_item_durations.has_key (item_id)) {
                continue;
            }

            int duration_seconds = queued_item_durations[item_id];
            if (duration_seconds <= 0) {
                continue;
            }

            values.add ("%s=%d".printf (item_id, duration_seconds));
        }

        var result = new string[values.size];
        for (int i = 0; i < values.size; i++) {
            result[i] = values[i];
        }

        return result;
    }

    private void sync_queue_settings () {
        var settings = Services.Settings.get_default ().settings;
        settings.set_strv ("focus-queue-item-ids", build_queue_id_settings_values ());
        settings.set_strv ("focus-queue-item-durations", build_queue_duration_settings_values ());
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

    public bool add_to_queue (Objects.Item item) {
        if (item == null || item.checked) {
            return false;
        }

        if (focus_item != null && focus_item.id == item.id) {
            return false;
        }

        if (queued_item_ids.contains (item.id)) {
            return false;
        }

        queued_item_ids.add (item.id);
        sync_queue_settings ();
        queue_changed ();
        return true;
    }

    public bool remove_from_queue (Objects.Item item) {
        if (item == null) {
            return false;
        }

        if (!queued_item_ids.contains (item.id)) {
            return false;
        }

        queued_item_ids.remove (item.id);
        queued_item_durations.unset (item.id);
        sync_queue_settings ();
        queue_changed ();
        return true;
    }

    public bool move_queue_item_up (Objects.Item item) {
        if (item == null) {
            return false;
        }

        int index = queued_item_ids.index_of (item.id);
        if (index <= 0) {
            return false;
        }

        string current_id = queued_item_ids[index];
        queued_item_ids[index] = queued_item_ids[index - 1];
        queued_item_ids[index - 1] = current_id;
        sync_queue_settings ();
        queue_changed ();
        return true;
    }

    public void clear_queue () {
        if (queued_item_ids.size == 0) {
            return;
        }

        queued_item_ids.clear ();
        queued_item_durations.clear ();
        sync_queue_settings ();
        queue_changed ();
    }

    public bool queue_contains (Objects.Item item) {
        if (item == null) {
            return false;
        }

        return queued_item_ids.contains (item.id);
    }

    public Gee.ArrayList<Objects.Item> get_queued_focus_items (int max_items = -1) {
        var result = new Gee.ArrayList<Objects.Item> ();
        var invalid_ids = new Gee.ArrayList<string> ();

        foreach (var item_id in queued_item_ids) {
            var item = Services.Store.instance ().get_item (item_id);
            if (item == null || item.checked) {
                invalid_ids.add (item_id);
                continue;
            }

            if (focus_item != null && focus_item.id == item.id) {
                invalid_ids.add (item_id);
                continue;
            }

            result.add (item);
            if (max_items > 0 && result.size >= max_items) {
                break;
            }
        }

        if (invalid_ids.size > 0) {
            foreach (var item_id in invalid_ids) {
                queued_item_ids.remove (item_id);
            }

            sync_queue_settings ();
            queue_changed ();
        }

        return result;
    }

    public Gee.ArrayList<Services.FocusQueueProposal> get_queue_schedule_proposals (int max_items = -1) {
        var proposals = new Gee.ArrayList<Services.FocusQueueProposal> ();
        var queued_items = get_queued_focus_items (max_items);

        if (queued_items.size == 0) {
            return proposals;
        }

        var base_anchor = get_queue_anchor_time ();
        var cursor = base_anchor;
        int simulated_round = current_round;
        int simulated_work_progress_seconds = 0;

        for (int index = 0; index < queued_items.size; index++) {
            var item = queued_items[index];
            bool uses_existing_duration = false;
            int duration_seconds = get_item_duration_seconds (item, out uses_existing_duration);
            int proposal_starting_round = simulated_round;
            int proposal_starting_work_progress_seconds = simulated_work_progress_seconds;
            var proposed_end = calculate_proposed_end (cursor, duration_seconds, ref simulated_round,
                                                       ref simulated_work_progress_seconds);
            bool rolls_to_tomorrow = !Utils.Datetime.is_same_day (cursor, proposed_end);

            if (rolls_to_tomorrow) {
                cursor = get_next_queue_anchor_time (base_anchor, cursor.add_days (1));
                proposal_starting_round = simulated_round;
                proposal_starting_work_progress_seconds = simulated_work_progress_seconds;
                proposed_end = calculate_proposed_end (cursor, duration_seconds, ref simulated_round,
                                                       ref simulated_work_progress_seconds);
            }

            proposals.add (new Services.FocusQueueProposal (
                item,
                cursor,
                proposed_end,
                duration_seconds,
                proposal_starting_round,
                proposal_starting_work_progress_seconds,
                proposal_conflicts_with_existing_schedule (item, cursor, proposed_end),
                rolls_to_tomorrow,
                uses_existing_duration
            ));

            if (index < queued_items.size - 1) {
                cursor = get_next_queue_cursor (base_anchor, proposed_end, ref simulated_round,
                                                ref simulated_work_progress_seconds);
            }
        }

        return proposals;
    }

    public Services.FocusQueueProposal ? get_queue_schedule_proposal_for_item (Objects.Item item) {
        if (item == null) {
            return null;
        }

        foreach (var proposal in get_queue_schedule_proposals ()) {
            if (proposal.item.id == item.id) {
                return proposal;
            }
        }

        return null;
    }

    public bool proposal_requires_schedule_update (Services.FocusQueueProposal ? proposal) {
        if (proposal == null || proposal.item == null) {
            return false;
        }

        var item = proposal.item;
        if (!item.has_due || item.due == null || item.due.datetime == null) {
            return true;
        }

        if (item.due.datetime.compare (proposal.proposed_start) != 0) {
            return true;
        }

        if (!item.due.has_end_date) {
            return true;
        }

        var existing_end = Utils.Datetime.get_todoist_datetime (item.due.end_date);
        if (existing_end == null) {
            return true;
        }

        return existing_end.compare (proposal.proposed_end) != 0;
    }

    public bool apply_queue_schedule_proposal (Services.FocusQueueProposal ? proposal) {
        if (proposal == null || proposal.item == null) {
            return false;
        }

        var due = proposal.item.due != null ? proposal.item.due.duplicate () : new Objects.DueDate ();
        due.date = Utils.Datetime.get_todoist_datetime_format (proposal.proposed_start);
        due.end_date = Utils.Datetime.get_todoist_datetime_format (proposal.proposed_end);

        queued_item_durations[proposal.item.id] = proposal.duration_seconds;
        proposal.item.update_due (due);
        sync_queue_settings ();
        queue_changed ();
        return true;
    }

    public bool apply_queue_schedule_duration (Services.FocusQueueProposal ? proposal, int duration_seconds) {
        if (proposal == null || proposal.item == null || duration_seconds <= 0) {
            return false;
        }

        var scheduled_end = get_queue_scheduled_end_for_duration (proposal, duration_seconds);
        var due = proposal.item.due != null ? proposal.item.due.duplicate () : new Objects.DueDate ();
        due.date = Utils.Datetime.get_todoist_datetime_format (proposal.proposed_start);
        due.end_date = Utils.Datetime.get_todoist_datetime_format (scheduled_end);

        queued_item_durations[proposal.item.id] = duration_seconds;
        proposal.item.update_due (due);
        sync_queue_settings ();
        queue_changed ();
        return true;
    }

    public GLib.DateTime get_queue_scheduled_end_for_duration (Services.FocusQueueProposal ? proposal, int duration_seconds) {
        if (proposal == null || duration_seconds <= 0) {
            return new GLib.DateTime.now_local ();
        }

        int simulated_round = proposal.starting_round;
        int simulated_work_progress_seconds = proposal.starting_work_progress_seconds;
        return calculate_proposed_end (proposal.proposed_start, duration_seconds, ref simulated_round,
                                       ref simulated_work_progress_seconds);
    }

    public Objects.Item ? promote_next_focus_item () {
        var queued_items = get_queued_focus_items (1);
        if (queued_items.size > 0) {
            change_focus_item (queued_items[0]);
            return queued_items[0];
        }

        if (!Services.Settings.get_default ().settings.get_boolean ("focus-auto-suggest")) {
            return null;
        }

        var suggested_item = suggest_focus_item ();
        if (suggested_item != null) {
            change_focus_item (suggested_item);
        }

        return suggested_item;
    }

    public Objects.Item ? suggest_focus_item () {
        var suggestions = get_suggested_focus_items ();
        if (suggestions.size > 0) {
            return suggestions[0];
        }
        return null;
    }

    public Gee.ArrayList<Objects.Item> get_suggested_focus_items (int max_items = 5) {
        var result = new Gee.ArrayList<Objects.Item> ();
        var now = new GLib.DateTime.now_local ();
        var added_ids = new Gee.HashSet<string> ();
        var queued_ids = new Gee.HashSet<string> ();

        foreach (var queued_item in get_queued_focus_items ()) {
            queued_ids.add (queued_item.id);
        }

        // First priority: scheduled items that are active now
        foreach (var item in Services.Store.instance ().get_items_by_scheduled (false)) {
            if (item == null || item.checked || item.due == null || item.due.datetime == null) {
                continue;
            }

            // Skip the currently focused item
            if (focus_item != null && item.id == focus_item.id) {
                continue;
            }

             if (queued_ids.contains (item.id)) {
                continue;
            }

            var start_dt = item.due.datetime;
            var end_dt = item.due.has_end_date ? Utils.Datetime.get_todoist_datetime (item.due.end_date) : null;

            if (end_dt != null) {
                if (start_dt.compare (now) <= 0 && end_dt.compare (now) >= 0) {
                    result.add (item);
                    added_ids.add (item.id);
                    if (result.size >= max_items) {
                        return result;
                    }
                }
            } else if (Utils.Datetime.is_today (start_dt)) {
                result.add (item);
                added_ids.add (item.id);
                if (result.size >= max_items) {
                    return result;
                }
            }
        }

        // Second priority: today's tasks
        var today_items = Services.Store.instance ().get_items_by_date (now, false);
        foreach (var item in today_items) {
            if (item == null || item.checked || added_ids.contains (item.id) || queued_ids.contains (item.id)) {
                continue;
            }

            // Skip the currently focused item
            if (focus_item != null && item.id == focus_item.id) {
                continue;
            }

            result.add (item);
            added_ids.add (item.id);
            if (result.size >= max_items) {
                return result;
            }
        }

        return result;
    }

    public void auto_suggest_if_enabled () {
        if (focus_item != null) {
            return;
        }

        promote_next_focus_item ();
    }

    private GLib.DateTime get_queue_anchor_time () {
        var now = new GLib.DateTime.now_local ();
        int minute = now.get_minute ();
        int rounded_minutes = (minute / 5) * 5;

        if (now.get_second () > 0 || minute % 5 != 0) {
            rounded_minutes += 5;
        }

        return new GLib.DateTime.local (
            now.get_year (),
            now.get_month (),
            now.get_day_of_month (),
            now.get_hour (),
            0,
            0
        ).add_minutes (rounded_minutes);
    }

    private GLib.DateTime get_next_queue_anchor_time (GLib.DateTime base_anchor, GLib.DateTime next_day) {
        return new GLib.DateTime.local (
            next_day.get_year (),
            next_day.get_month (),
            next_day.get_day_of_month (),
            base_anchor.get_hour (),
            base_anchor.get_minute (),
            0
        );
    }

    private GLib.DateTime get_next_queue_cursor (GLib.DateTime base_anchor, GLib.DateTime current_end,
                                                 ref int simulated_round,
                                                 ref int simulated_work_progress_seconds) {
        int break_seconds = 0;

        if (queue_uses_pomodoro_session_breaks ()) {
            if (simulated_work_progress_seconds < get_work_duration_seconds ()) {
                return current_end;
            }

            break_seconds = get_break_duration_seconds_for_round (simulated_round);
            advance_round_after_break (ref simulated_round);
            simulated_work_progress_seconds = 0;
        } else {
            break_seconds = get_between_task_break_seconds ();
            simulated_work_progress_seconds = 0;
        }

        var next_cursor = current_end.add_seconds (break_seconds);

        if (!Utils.Datetime.is_same_day (current_end, next_cursor)) {
            return get_next_queue_anchor_time (base_anchor, next_cursor);
        }

        return next_cursor;
    }

    private int get_item_duration_seconds (Objects.Item item, out bool uses_existing_duration) {
        uses_existing_duration = false;

        if (item != null && queued_item_durations.has_key (item.id)) {
            int queued_duration = queued_item_durations[item.id];
            if (queued_duration > 0) {
                uses_existing_duration = true;
                return queued_duration;
            }
        }

        if (item != null && item.has_due && item.due != null && item.due.datetime != null && item.due.has_end_date) {
            var end_dt = Utils.Datetime.get_todoist_datetime (item.due.end_date);
            if (end_dt != null) {
                int duration = (int) (end_dt.difference (item.due.datetime) / TimeSpan.SECOND);
                if (duration > 0) {
                    uses_existing_duration = true;
                    return duration;
                }
            }
        }

        return get_work_duration_seconds ();
    }

    private int get_break_duration_seconds_for_round (int simulated_round) {
        return simulated_round >= get_rounds_before_long_break ()
            ? get_long_break_duration_seconds ()
            : get_short_break_duration_seconds ();
    }

    private void advance_round_after_break (ref int simulated_round) {
        if (simulated_round >= get_rounds_before_long_break ()) {
            simulated_round = 1;
        } else {
            simulated_round++;
        }
    }

    private GLib.DateTime calculate_proposed_end (GLib.DateTime start, int duration_seconds, ref int simulated_round,
                                                  ref int simulated_work_progress_seconds) {
        if (!queue_uses_pomodoro_session_breaks ()) {
            simulated_work_progress_seconds = 0;
            return start.add_seconds (duration_seconds);
        }

        var cursor = start;
        int remaining_seconds = duration_seconds;
        int work_duration_seconds = get_work_duration_seconds ();

        while (remaining_seconds > 0) {
            int available_work_seconds = work_duration_seconds - simulated_work_progress_seconds;

            if (available_work_seconds <= 0) {
                cursor = cursor.add_seconds (get_break_duration_seconds_for_round (simulated_round));
                advance_round_after_break (ref simulated_round);
                simulated_work_progress_seconds = 0;
                continue;
            }

            int chunk = int.min (remaining_seconds, available_work_seconds);
            cursor = cursor.add_seconds (chunk);
            remaining_seconds -= chunk;
            simulated_work_progress_seconds += chunk;
        }

        return cursor;
    }

    private bool proposal_conflicts_with_existing_schedule (Objects.Item item, GLib.DateTime proposed_start, GLib.DateTime proposed_end) {
        if (item == null || !item.has_due || item.due == null || item.due.datetime == null) {
            return false;
        }

        if (item.due.datetime.compare (proposed_start) != 0) {
            return true;
        }

        if (item.due.has_end_date) {
            var existing_end = Utils.Datetime.get_todoist_datetime (item.due.end_date);
            if (existing_end == null) {
                return true;
            }

            return existing_end.compare (proposed_end) != 0;
        }

        return false;
    }

    public void start () {
        if (focus_item == null) {
            auto_suggest_if_enabled ();
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

    private void restore_queue () {
        var settings = Services.Settings.get_default ().settings;
        var stored_ids = settings.get_strv ("focus-queue-item-ids");
        var stored_durations = settings.get_strv ("focus-queue-item-durations");
        queued_item_ids.clear ();
        queued_item_durations.clear ();

        foreach (var entry in stored_durations) {
            if (entry == null || entry == "") {
                continue;
            }

            int separator_index = entry.last_index_of_char ('=');
            if (separator_index <= 0 || separator_index >= entry.length - 1) {
                continue;
            }

            string item_id = entry.substring (0, separator_index);
            int duration_seconds = int.parse (entry.substring (separator_index + 1));

            if (duration_seconds > 0) {
                queued_item_durations[item_id] = duration_seconds;
            }
        }

        foreach (var item_id in stored_ids) {
            if (item_id == null || item_id == "") {
                continue;
            }

            var item = Services.Store.instance ().get_item (item_id);
            if (item == null || item.checked) {
                continue;
            }

            if (focus_item != null && focus_item.id == item.id) {
                queued_item_durations.unset (item_id);
                continue;
            }

            queued_item_ids.add (item_id);
        }

        var stale_duration_ids = new Gee.ArrayList<string> ();
        foreach (var item_id in queued_item_durations.keys) {
            if (!queued_item_ids.contains (item_id)) {
                stale_duration_ids.add (item_id);
            }
        }

        foreach (var item_id in stale_duration_ids) {
            queued_item_durations.unset (item_id);
        }

        sync_queue_settings ();
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