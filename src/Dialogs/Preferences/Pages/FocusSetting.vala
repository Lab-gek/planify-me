/*
 * Copyright © 2025 Alain M. (https://github.com/alainm23/planify)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * Authored by: Alain M. <alainmh23@gmail.com>
 */

public class Dialogs.Preferences.Pages.FocusSetting : Dialogs.Preferences.Pages.BasePage {
    public FocusSetting (Adw.PreferencesDialog preferences_dialog) {
        Object (
            preferences_dialog: preferences_dialog,
            title: _("Focus")
        );
    }

    ~FocusSetting () {
        debug ("Destroying - Dialogs.Preferences.Pages.FocusSetting\n");
    }

    construct {
        var timer_group = new Adw.PreferencesGroup () {
            title = _("Pomodoro Timer"),
            margin_start = 3,
            margin_end = 3,
            margin_top = 12
        };

        var work_row = new Adw.SpinRow.with_range (1, 90, 1) {
            valign = Gtk.Align.CENTER,
            title = _("Work Duration"),
            subtitle = _("Minutes per work interval"),
            value = Services.Settings.get_default ().settings.get_int ("focus-work-duration")
        };

        var short_break_row = new Adw.SpinRow.with_range (1, 45, 1) {
            valign = Gtk.Align.CENTER,
            title = _("Short Break"),
            subtitle = _("Minutes between work intervals"),
            value = Services.Settings.get_default ().settings.get_int ("focus-short-break")
        };

        var long_break_row = new Adw.SpinRow.with_range (1, 90, 1) {
            valign = Gtk.Align.CENTER,
            title = _("Long Break"),
            subtitle = _("Minutes after completing all rounds"),
            value = Services.Settings.get_default ().settings.get_int ("focus-long-break")
        };

        var rounds_row = new Adw.SpinRow.with_range (1, 12, 1) {
            valign = Gtk.Align.CENTER,
            title = _("Rounds Before Long Break"),
            subtitle = _("How many work rounds before the long break"),
            value = Services.Settings.get_default ().settings.get_int ("focus-rounds-before-long-break")
        };

        timer_group.add (work_row);
        timer_group.add (short_break_row);
        timer_group.add (long_break_row);
        timer_group.add (rounds_row);

        var behavior_group = new Adw.PreferencesGroup () {
            title = _("Behavior"),
            margin_start = 3,
            margin_end = 3,
            margin_top = 12
        };

        var auto_suggest_row = new Adw.SwitchRow () {
            title = _("Auto-suggest Scheduled Task"),
            subtitle = _("Suggest task based on current schedule when opening Focus view")
        };

        var bonus_points_row = new Adw.SpinRow.with_range (0, 20, 1) {
            valign = Gtk.Align.CENTER,
            title = _("Focus Bonus Points"),
            subtitle = _("Extra points for completing a task during Focus mode")
        };
        bonus_points_row.value = Services.Settings.get_default ().settings.get_int ("focus-bonus-points");

        behavior_group.add (auto_suggest_row);
        behavior_group.add (bonus_points_row);

        var note_group = new Adw.PreferencesGroup () {
            margin_start = 3,
            margin_end = 3,
            margin_top = 12
        };

        note_group.add (new Adw.ActionRow () {
            title = _("Points + Breaks"),
            subtitle = _("Pomodoro break time is added to grace period so breaks do not cause late penalties")
        });

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 12,
            margin_top = 6
        };
        content_box.append (timer_group);
        content_box.append (behavior_group);
        content_box.append (note_group);

        var scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            hexpand = true,
            vexpand = true,
            child = content_box
        };

        var toolbar_view = new Adw.ToolbarView () {
            content = scrolled_window
        };
        toolbar_view.add_top_bar (new Adw.HeaderBar ());

        child = toolbar_view;

        Services.Settings.get_default ().settings.bind (
            "focus-auto-suggest",
            auto_suggest_row,
            "active",
            GLib.SettingsBindFlags.DEFAULT
        );

        signal_map[work_row.output.connect (() => {
            Services.Settings.get_default ().settings.set_int ("focus-work-duration", (int) work_row.value);
        })] = work_row;

        signal_map[short_break_row.output.connect (() => {
            Services.Settings.get_default ().settings.set_int ("focus-short-break", (int) short_break_row.value);
        })] = short_break_row;

        signal_map[long_break_row.output.connect (() => {
            Services.Settings.get_default ().settings.set_int ("focus-long-break", (int) long_break_row.value);
        })] = long_break_row;

        signal_map[rounds_row.output.connect (() => {
            Services.Settings.get_default ().settings.set_int ("focus-rounds-before-long-break", (int) rounds_row.value);
        })] = rounds_row;

        signal_map[bonus_points_row.output.connect (() => {
            Services.Settings.get_default ().settings.set_int ("focus-bonus-points", (int) bonus_points_row.value);
        })] = bonus_points_row;

        destroy.connect (() => {
            clean_up ();
        });
    }
}
