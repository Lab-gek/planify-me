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

[DBus (name = "io.github.lab_gek.bluplan")]
public class Services.DBusServer : Object {
    private const string DBUS_NAME = "io.github.lab_gek.bluplan";
    private const string DBUS_PATH = "/io/github/lab_gek/bluplan";

    private static GLib.Once<DBusServer> instance;

    public static unowned DBusServer get_default () {
        return instance.once (() => { return new DBusServer (); });
    }

    // Legacy signals
    public signal void item_added (string id);

    // Focus-related signals
    public signal void focus_state_changed (string state, bool running);
    public signal void timer_tick (int seconds_remaining);
    public signal void focused_task_changed (string item_id, string content);

    // Focus-related properties
    public string focus_state {
        owned get {
            return get_focus_state_string (Services.FocusManager.get_default ().state);
        }
    }

    public bool focus_running {
        get {
            return Services.FocusManager.get_default ().running;
        }
    }

    public int seconds_remaining {
        get {
            return Services.FocusManager.get_default ().seconds_remaining;
        }
    }

    public int current_round {
        get {
            return Services.FocusManager.get_default ().current_round;
        }
    }

    public string focused_item_id {
        owned get {
            var item = Services.FocusManager.get_default ().focus_item;
            return item != null ? item.id : "";
        }
    }

    public string focused_item_content {
        owned get {
            var item = Services.FocusManager.get_default ().focus_item;
            return item != null ? item.content : "";
        }
    }

    construct {
        Bus.own_name (
            BusType.SESSION,
            DBUS_NAME,
            BusNameOwnerFlags.NONE,
            (connection) => on_bus_aquired (connection),
            () => {},
            null
        );

        connect_focus_signals ();
    }

    private void connect_focus_signals () {
        var focus_manager = Services.FocusManager.get_default ();

        focus_manager.state_changed.connect (() => {
            focus_state_changed (
                get_focus_state_string (focus_manager.state),
                focus_manager.running
            );
            notify_property ("focus-state");
            notify_property ("focus-running");
        });

        focus_manager.timer_tick.connect (() => {
            timer_tick (focus_manager.seconds_remaining);
            notify_property ("seconds-remaining");
            notify_property ("current-round");
        });

        focus_manager.focus_item_changed.connect (() => {
            var item = focus_manager.focus_item;
            focused_task_changed (
                item != null ? item.id : "",
                item != null ? item.content : ""
            );
            notify_property ("focused-item-id");
            notify_property ("focused-item-content");
        });
    }

    private string get_focus_state_string (FocusState state) {
        switch (state) {
            case FocusState.WORKING:
                return "working";
            case FocusState.SHORT_BREAK:
                return "short_break";
            case FocusState.LONG_BREAK:
                return "long_break";
            case FocusState.IDLE:
            default:
                return "idle";
        }
    }

    // Legacy method
    public void add_item (string id) throws IOError, DBusError {
        item_added (id);
    }

    // Focus control methods
    public void start_focus (string item_id) throws IOError, DBusError {
        var focus_manager = Services.FocusManager.get_default ();
        
        if (item_id != null && item_id != "") {
            var item = Services.Store.instance ().get_item (item_id);
            if (item != null) {
                focus_manager.change_focus_item (item);
            }
        }
        
        focus_manager.start ();
    }

    public void pause_focus () throws IOError, DBusError {
        Services.FocusManager.get_default ().pause ();
    }

    public void resume_focus () throws IOError, DBusError {
        Services.FocusManager.get_default ().resume ();
    }

    public void stop_focus () throws IOError, DBusError {
        Services.FocusManager.get_default ().stop ();
    }

    public void skip_break () throws IOError, DBusError {
        Services.FocusManager.get_default ().skip_break ();
    }

    public void complete_focused_task () throws IOError, DBusError {
        var focus_manager = Services.FocusManager.get_default ();
        var item = focus_manager.focus_item;
        
        if (item != null) {
            item.checked = true;
            Services.Store.instance ().update_item (item);
        }
    }

    public string get_next_suggested_task () throws IOError, DBusError {
        var focus_manager = Services.FocusManager.get_default ();
        var items = focus_manager.get_suggested_focus_items (5);
        
        // Return the first upcoming task (which excludes the current focus_item)
        if (items.size > 0) {
            var item = items[0];
            var json = new Json.Object ();
            json.set_string_member ("id", item.id);
            json.set_string_member ("content", item.content);
            json.set_int_member ("priority", item.priority);
            
            if (item.due != null && item.due.datetime != null) {
                json.set_string_member ("due_date", item.due.datetime.to_string ());
            }
            
            var generator = new Json.Generator ();
            var root = new Json.Node (Json.NodeType.OBJECT);
            root.set_object (json);
            generator.set_root (root);
            
            return generator.to_data (null);
        }
        
        return "{}";
    }

    public string get_upcoming_tasks () throws IOError, DBusError {
        var focus_manager = Services.FocusManager.get_default ();
        var items = focus_manager.get_suggested_focus_items (5);
        
        var json_array = new Json.Array ();
        
        foreach (var item in items) {
            var json = new Json.Object ();
            json.set_string_member ("id", item.id);
            json.set_string_member ("content", item.content);
            json.set_int_member ("priority", item.priority);
            
            if (item.due != null && item.due.datetime != null) {
                json.set_string_member ("due_date", item.due.datetime.to_string ());
            }
            
            var node = new Json.Node (Json.NodeType.OBJECT);
            node.set_object (json);
            json_array.add_element (node);
        }
        
        var generator = new Json.Generator ();
        var root = new Json.Node (Json.NodeType.ARRAY);
        root.set_array (json_array);
        generator.set_root (root);
        
        return generator.to_data (null);
    }

    private void on_bus_aquired (DBusConnection conn) {
        try {
            conn.register_object (DBUS_PATH, get_default ());
        } catch (Error e) {
            error (e.message);
        }
    }
}

[DBus (name = "io.github.lab_gek.bluplan")]
public errordomain DBusServerError {
    SOME_ERROR
}
