/* settingsManager.js
 *
 * Manages extension settings using GSettings
 */

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

export class SettingsManager {
    constructor(extensionPath) {
        // Load settings schema
        const schemaDir = Gio.File.new_for_path(extensionPath).get_child('schemas');
        
        let schemaSource;
        if (schemaDir.query_exists(null)) {
            schemaSource = Gio.SettingsSchemaSource.new_from_directory(
                schemaDir.get_path(),
                Gio.SettingsSchemaSource.get_default(),
                false
            );
        } else {
            schemaSource = Gio.SettingsSchemaSource.get_default();
        }
        
        const schemaObj = schemaSource.lookup(
            'org.gnome.shell.extensions.bluplan-focus',
            false
        );
        
        if (!schemaObj) {
            throw new Error('Schema not found');
        }
        
        this._settings = new Gio.Settings({ settings_schema: schemaObj });
        this._signals = {};
    }
    
    // View mode
    get viewMode() {
        return this._settings.get_string('view-mode');
    }
    
    set viewMode(value) {
        this._settings.set_string('view-mode', value);
    }
    
    // Element visibility
    get showTimer() {
        if (this.viewMode !== 'custom') {
            return this.viewMode === 'expanded';
        }
        return this._settings.get_boolean('show-timer');
    }
    
    set showTimer(value) {
        this._settings.set_boolean('show-timer', value);
    }
    
    get showControls() {
        return this._settings.get_boolean('show-controls');
    }
    
    set showControls(value) {
        this._settings.set_boolean('show-controls', value);
    }
    
    get showTaskName() {
        if (this.viewMode === 'compact') {
            return false;
        }
        if (this.viewMode === 'expanded') {
            return true;
        }
        return this._settings.get_boolean('show-task-name');
    }
    
    set showTaskName(value) {
        this._settings.set_boolean('show-task-name', value);
    }
    
    get showNextTask() {
        return this._settings.get_boolean('show-next-task');
    }
    
    set showNextTask(value) {
        this._settings.set_boolean('show-next-task', value);
    }
    
    // Button position
    get buttonPosition() {
        return this._settings.get_string('button-position');
    }
    
    set buttonPosition(value) {
        this._settings.set_string('button-position', value);
    }
    
    // Connect to settings changes
    connect(key, callback) {
        const signalId = this._settings.connect(`changed::${key}`, callback);
        
        if (!this._signals[key]) {
            this._signals[key] = [];
        }
        this._signals[key].push(signalId);
        
        return signalId;
    }
    
    disconnect(signalId) {
        this._settings.disconnect(signalId);
    }
    
    // Check if element should be visible
    isElementVisible(element) {
        switch (element) {
            case 'timer':
                return this.showTimer;
            case 'controls':
                return this.showControls;
            case 'task-name':
                return this.showTaskName;
            case 'next-task':
                return this.showNextTask;
            default:
                return false;
        }
    }
    
    destroy() {
        // Disconnect all signals
        Object.values(this._signals).flat().forEach(id => {
            this._settings.disconnect(id);
        });
        this._signals = {};
        this._settings = null;
    }
}
