/*
 * Copyright © 2023 Alain M. (https://github.com/alainm23/planify)
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

public class Dialogs.PointsInfoDialog : Adw.Dialog {
    public PointsInfoDialog () {
        Object (
            title: _("How Points Work"),
            content_width: 450,
            content_height: 600
        );
    }

    ~PointsInfoDialog () {
        debug ("Destroying - Dialogs.PointsInfoDialog\n");
    }

    construct {
        var toolbar_view = new Adw.ToolbarView ();

        var headerbar = new Adw.HeaderBar ();
        headerbar.add_css_class ("flat");
        toolbar_view.add_top_bar (headerbar);

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.add_css_class ("padding-12");

        // Overview Section
        var overview_group = new Adw.PreferencesGroup () {
            title = _("Overview")
        };

        var overview_label = new Gtk.Label (_("Earn points by completing scheduled tasks. Points reflect your productivity and time management skills.")) {
            wrap = true,
            xalign = 0
        };
        overview_label.add_css_class ("body");

        var overview_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        overview_box.append (overview_label);
        overview_group.add (overview_box);

        // Formula Section
        var formula_group = new Adw.PreferencesGroup () {
            title = _("Point Calculation")
        };

        var formula_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        formula_label.label = _("<b>Base Points + Bonuses − Penalties = Total Points</b>");
        formula_label.add_css_class ("body");

        var formula_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12) {
            margin_top = 6
        };
        formula_box.append (formula_label);

        // Base Points
        var base_points_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        base_points_label.label = _("<b>Base Points</b>\n1 point per 5 minutes of scheduled duration, maximum 24 points (2 hours).\n\n<tt>Examples:</tt>\n  • 15 min task = 3 pts\n  • 30 min task = 6 pts\n  • 60 min task = 12 pts\n  • 2+ hour task = 24 pts (capped)");
        base_points_label.add_css_class ("caption");
        formula_box.append (base_points_label);

        // Early Bonus
        var early_bonus_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        early_bonus_label.label = _("<b>Early Bonus</b>\n+1 point when completed 5 or more minutes early.");
        early_bonus_label.add_css_class ("caption");
        formula_box.append (early_bonus_label);

        // Focus Bonus
        int focus_bonus = Services.Settings.get_default ().settings.get_int ("focus-bonus-points");
        var focus_bonus_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        focus_bonus_label.label = _("<b>Focus Bonus</b>\n+%d points when completed in Focus Mode.").printf (focus_bonus);
        focus_bonus_label.add_css_class ("caption");
        formula_box.append (focus_bonus_label);

        // Late Penalties
        var penalty_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        penalty_label.label = _("<b>Late Penalties</b>\nApplied after the grace period based on your penalty curve setting:\n\n<tt>Relaxed:</tt>\n  • 0-15 min late = 75%% of points\n  • 15-45 min late = 50%% of points\n  • Over 45 min = 25%% of points\n\n<tt>Balanced:</tt>\n  • 0-10 min late = 50%% of points\n  • 10-30 min late = 25%% of points\n  • Over 30 min = 0%% points\n\n<tt>Strict:</tt>\n  • 0-5 min late = 50%% of points\n  • 5-15 min late = 25%% of points\n  • Over 15 min = 0%% points");
        penalty_label.add_css_class ("caption");
        formula_box.append (penalty_label);

        formula_group.add (formula_box);

        // Important Notes Section
        var notes_group = new Adw.PreferencesGroup () {
            title = _("Important Notes")
        };

        var notes_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        notes_label.label = _("• Tasks need scheduled start <b>and</b> end times to earn points\n• Grace period can be configured in settings\n• 'Assume Working' mode disables all late penalties\n• Focus Mode extends grace period during breaks");
        notes_label.add_css_class ("body");

        var notes_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        notes_box.append (notes_label);
        notes_group.add (notes_box);

        // Footer
        var settings_label = new Gtk.Label (null) {
            wrap = true,
            xalign = 0,
            use_markup = true
        };
        settings_label.label = _("<span foreground='#888888'><small>Adjust these settings in <b>Preferences → Tasks → Points</b></small></span>");
        settings_label.add_css_class ("caption");

        var footer_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_top = 12
        };
        footer_box.append (settings_label);

        // Add all groups to content
        content_box.append (overview_group);
        content_box.append (formula_group);
        content_box.append (notes_group);
        content_box.append (footer_box);

        var scrolled_window = new Gtk.ScrolledWindow () {
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            vscrollbar_policy = Gtk.PolicyType.AUTOMATIC,
            child = content_box
        };

        toolbar_view.content = scrolled_window;
        child = toolbar_view;
    }
}
