/* prefs.js
 *
 * Preferences UI for BluPlan Focus extension
 */

import Adw from 'gi://Adw';
import Gtk from 'gi://Gtk';
import Gio from 'gi://Gio';
import { ExtensionPreferences } from 'resource:///org/gnome/Shell/Extensions/js/extensions/prefs.js';

export default class BluPlanFocusPreferences extends ExtensionPreferences {
    fillPreferencesWindow(window) {
        // Load settings
        const settings = this.getSettings('org.gnome.shell.extensions.bluplan-focus');
        
        // Create preferences page
        const page = new Adw.PreferencesPage({
            title: 'General',
            icon_name: 'preferences-system-symbolic'
        });
        window.add(page);
        
        // View Mode Group
        const viewModeGroup = new Adw.PreferencesGroup({
            title: 'Display Mode',
            description: 'Control how the extension appears in the top bar'
        });
        page.add(viewModeGroup);
        
        // View mode combo row
        const viewModeRow = new Adw.ComboRow({
            title: 'View Mode',
            subtitle: 'Choose how much information to display',
            model: new Gtk.StringList({
                strings: ['Compact (icon only)', 'Expanded (icon + timer + task)', 'Custom (configure below)']
            })
        });
        
        // Map indices to values
        const viewModeMap = ['compact', 'expanded', 'custom'];
        const currentMode = settings.get_string('view-mode');
        viewModeRow.selected = viewModeMap.indexOf(currentMode);
        
        viewModeRow.connect('notify::selected', (widget) => {
            settings.set_string('view-mode', viewModeMap[widget.selected]);
        });
        
        viewModeGroup.add(viewModeRow);
        
        // Custom Element Visibility Group
        const elementsGroup = new Adw.PreferencesGroup({
            title: 'Element Visibility',
            description: 'Choose which elements to display (when using Custom mode)'
        });
        page.add(elementsGroup);
        
        // Show timer switch
        const showTimerRow = new Adw.ActionRow({
            title: 'Show Timer',
            subtitle: 'Display countdown timer in the panel'
        });
        const showTimerSwitch = new Gtk.Switch({
            active: settings.get_boolean('show-timer'),
            valign: Gtk.Align.CENTER
        });
        settings.bind('show-timer', showTimerSwitch, 'active', Gio.SettingsBindFlags.DEFAULT);
        showTimerRow.add_suffix(showTimerSwitch);
        showTimerRow.activatable_widget = showTimerSwitch;
        elementsGroup.add(showTimerRow);
        
        // Show task name switch
        const showTaskNameRow = new Adw.ActionRow({
            title: 'Show Task Name',
            subtitle: 'Display the currently focused task name'
        });
        const showTaskNameSwitch = new Gtk.Switch({
            active: settings.get_boolean('show-task-name'),
            valign: Gtk.Align.CENTER
        });
        settings.bind('show-task-name', showTaskNameSwitch, 'active', Gio.SettingsBindFlags.DEFAULT);
        showTaskNameRow.add_suffix(showTaskNameSwitch);
        showTaskNameRow.activatable_widget = showTaskNameSwitch;
        elementsGroup.add(showTaskNameRow);
        
        // Show controls switch
        const showControlsRow = new Adw.ActionRow({
            title: 'Show Controls',
            subtitle: 'Display control buttons in the popup menu'
        });
        const showControlsSwitch = new Gtk.Switch({
            active: settings.get_boolean('show-controls'),
            valign: Gtk.Align.CENTER
        });
        settings.bind('show-controls', showControlsSwitch, 'active', Gio.SettingsBindFlags.DEFAULT);
        showControlsRow.add_suffix(showControlsSwitch);
        showControlsRow.activatable_widget = showControlsSwitch;
        elementsGroup.add(showControlsRow);
        
        // Show next task switch
        const showNextTaskRow = new Adw.ActionRow({
            title: 'Show Next Task',
            subtitle: 'Display next scheduled task in the menu'
        });
        const showNextTaskSwitch = new Gtk.Switch({
            active: settings.get_boolean('show-next-task'),
            valign: Gtk.Align.CENTER
        });
        settings.bind('show-next-task', showNextTaskSwitch, 'active', Gio.SettingsBindFlags.DEFAULT);
        showNextTaskRow.add_suffix(showNextTaskSwitch);
        showNextTaskRow.activatable_widget = showNextTaskSwitch;
        elementsGroup.add(showNextTaskRow);
        
        // Button Position Group
        const positionGroup = new Adw.PreferencesGroup({
            title: 'Button Position',
            description: 'Choose where the button appears in the top bar'
        });
        page.add(positionGroup);
        
        // Position combo row
        const positionRow = new Adw.ComboRow({
            title: 'Panel Position',
            subtitle: 'Location of the button in the top bar',
            model: new Gtk.StringList({
                strings: ['Left', 'Center', 'Right']
            })
        });
        
        const positionMap = ['left', 'center', 'right'];
        const currentPosition = settings.get_string('button-position');
        positionRow.selected = positionMap.indexOf(currentPosition);
        
        positionRow.connect('notify::selected', (widget) => {
            settings.set_string('button-position', positionMap[widget.selected]);
        });
        
        positionGroup.add(positionRow);
        
        // About Group
        const aboutGroup = new Adw.PreferencesGroup({
            title: 'About'
        });
        page.add(aboutGroup);
        
        const aboutRow = new Adw.ActionRow({
            title: 'BluPlan Focus Extension',
            subtitle: 'Display BluPlan Pomodoro timer in GNOME Shell top bar'
        });
        aboutGroup.add(aboutRow);
        
        const linkRow = new Adw.ActionRow({
            title: 'BluPlan Project'
        });
        const linkButton = new Gtk.LinkButton({
            label: 'GitHub',
            uri: 'https://github.com/alainm23/planify',
            valign: Gtk.Align.CENTER
        });
        linkRow.add_suffix(linkButton);
        aboutGroup.add(linkRow);
    }
}
