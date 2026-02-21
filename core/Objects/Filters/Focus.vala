/*
 * Copyright © 2026 Alain M. (https://github.com/alainm23/planify)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 */

public class Objects.Filters.Focus : Objects.BaseObject {
    private static Focus ? _instance;
    public static Focus get_default () {
        if (_instance == null) {
            _instance = new Focus ();
        }

        return _instance;
    }

    construct {
        name = _("Focus");
        keywords = _("focus") + ";" + _("pomodoro") + ";" + _("filters");
        icon_name = "timer-symbolic";
        view_id = "focus";
        color = "#c061cb";
    }

    public override int update_count () {
        return Services.Settings.get_default ().settings.get_string ("focus-current-item-id") != "" ? 1 : 0;
    }

    public override void count_update () {
        _item_count = update_count ();
        count_updated ();
    }
}