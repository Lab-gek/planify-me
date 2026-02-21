/* extension.js
 *
 * GNOME Shell extension entry point
 */

import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

import { BluPlanClient } from './dbusClient.js';
import { SettingsManager } from './settingsManager.js';
import { BluPlanPanelButton } from './panelButton.js';

export default class BluPlanFocusExtension extends Extension {
    constructor(metadata) {
        super(metadata);
        this._panelButton = null;
        this._dbusClient = null;
        this._settings = null;
    }
    
    enable() {
        console.log('Enabling BluPlan Focus extension');
        
        try {
            // Initialize settings
            this._settings = new SettingsManager(this.path);
            
            // Initialize DBus client
            this._dbusClient = new BluPlanClient();
            this._dbusClient.initialize();
            
            // Create panel button
            this._panelButton = new BluPlanPanelButton(this._dbusClient, this._settings);
            
            // Add to panel based on position setting
            const position = this._settings.buttonPosition;
            let box;
            
            switch (position) {
                case 'left':
                    box = Main.panel._leftBox;
                    break;
                case 'center':
                    box = Main.panel._centerBox;
                    break;
                case 'right':
                default:
                    box = Main.panel._rightBox;
                    break;
            }
            
            Main.panel.addToStatusArea('bluplan-focus', this._panelButton, 0, position);
            
        } catch (e) {
            console.error('Failed to enable BluPlan Focus extension:', e);
        }
    }
    
    disable() {
        console.log('Disabling BluPlan Focus extension');
        
        if (this._panelButton) {
            this._panelButton.destroy();
            this._panelButton = null;
        }
        
        if (this._dbusClient) {
            this._dbusClient.destroy();
            this._dbusClient = null;
        }
        
        if (this._settings) {
            this._settings.destroy();
            this._settings = null;
        }
    }
}
