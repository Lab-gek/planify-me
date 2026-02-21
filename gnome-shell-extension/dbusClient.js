/* dbusClient.js
 *
 * DBus client for communicating with BluPlan application
 */

import Gio from 'gi://Gio';
import GLib from 'gi://GLib';

const DBUS_NAME = 'io.github.lab_gek.bluplan';
const DBUS_PATH = '/io/github/lab_gek/bluplan';

const BluPlanIface = `
<node>
  <interface name="${DBUS_NAME}">
    <property name="FocusState" type="s" access="read"/>
    <property name="FocusRunning" type="b" access="read"/>
    <property name="SecondsRemaining" type="i" access="read"/>
    <property name="CurrentRound" type="i" access="read"/>
    <property name="FocusedItemId" type="s" access="read"/>
    <property name="FocusedItemContent" type="s" access="read"/>
    
    <method name="StartFocus">
      <arg type="s" direction="in" name="item_id"/>
    </method>
    <method name="PauseFocus"/>
    <method name="ResumeFocus"/>
    <method name="StopFocus"/>
    <method name="SkipBreak"/>
    <method name="CompleteFocusedTask"/>
    <method name="GetNextSuggestedTask">
      <arg type="s" direction="out" name="task_json"/>
    </method>
    
    <signal name="FocusStateChanged">
      <arg type="s" name="state"/>
      <arg type="b" name="running"/>
    </signal>
    <signal name="TimerTick">
      <arg type="i" name="seconds_remaining"/>
    </signal>
    <signal name="FocusedTaskChanged">
      <arg type="s" name="item_id"/>
      <arg type="s" name="content"/>
    </signal>
  </interface>
</node>`;

const BluPlanProxyClass = Gio.DBusProxy.makeProxyWrapper(BluPlanIface);

export class BluPlanClient {
    constructor() {
        this._proxy = null;
        this._nameWatcherId = 0;
        this._isAvailable = false;
        
        // Signals
        this._signals = {};
    }
    
    async initialize() {
        // Watch for BluPlan app availability
        this._nameWatcherId = Gio.bus_watch_name(
            Gio.BusType.SESSION,
            DBUS_NAME,
            Gio.BusNameWatcherFlags.NONE,
            this._onNameAppeared.bind(this),
            this._onNameVanished.bind(this)
        );
    }
    
    _onNameAppeared() {
        this._isAvailable = true;
        this._createProxy();
    }
    
    _onNameVanished() {
        this._isAvailable = false;
        this._proxy = null;
        this._emitSignal('availability-changed', false);
    }
    
    _createProxy() {
        try {
            this._proxy = new BluPlanProxyClass(
                Gio.DBus.session,
                DBUS_NAME,
                DBUS_PATH,
                (proxy, error) => {
                    if (error) {
                        console.error('Failed to create BluPlan DBus proxy:', error);
                        this._isAvailable = false;
                        return;
                    }
                    
                    this._onProxyReady();
                }
            );
        } catch (e) {
            console.error('Failed to create BluPlan DBus proxy:', e);
            this._isAvailable = false;
        }
    }
    
    _onProxyReady() {
        if (!this._proxy) return;
        
        // Connect to property changes
        this._proxy.connect('g-properties-changed', (proxy, changed, invalidated) => {
            const changedProps = changed.deepUnpack();
            
            if ('FocusState' in changedProps || 'FocusRunning' in changedProps) {
                const state = this._proxy.FocusState || 'idle';
                const running = this._proxy.FocusRunning || false;
                this._emitSignal('focus-state-changed', { state, running });
            }
            
            if ('SecondsRemaining' in changedProps) {
                const seconds = this._proxy.SecondsRemaining || 0;
                this._emitSignal('timer-tick', seconds);
            }
            
            if ('FocusedItemId' in changedProps || 'FocusedItemContent' in changedProps) {
                const itemId = this._proxy.FocusedItemId || '';
                const content = this._proxy.FocusedItemContent || '';
                this._emitSignal('focused-task-changed', { itemId, content });
            }
        });
        
        // Connect to D-Bus signals
        this._proxy.connectSignal('FocusStateChanged', (proxy, sender, [state, running]) => {
            this._emitSignal('focus-state-changed', { state, running });
        });
        
        this._proxy.connectSignal('TimerTick', (proxy, sender, [seconds]) => {
            this._emitSignal('timer-tick', seconds);
        });
        
        this._proxy.connectSignal('FocusedTaskChanged', (proxy, sender, [itemId, content]) => {
            this._emitSignal('focused-task-changed', { itemId, content });
        });
        
        this._emitSignal('availability-changed', true);
    }
    
    // Public API
    get isAvailable() {
        return this._isAvailable && this._proxy !== null;
    }
    
    getState() {
        if (!this.isAvailable) return null;
        
        try {
            return {
                state: this._proxy.FocusState || 'idle',
                running: this._proxy.FocusRunning || false,
                secondsRemaining: this._proxy.SecondsRemaining || 0,
                currentRound: this._proxy.CurrentRound || 1,
                focusedItemId: this._proxy.FocusedItemId || '',
                focusedItemContent: this._proxy.FocusedItemContent || ''
            };
        } catch (e) {
            console.error('Failed to get BluPlan state:', e);
            return null;
        }
    }
    
    startFocus(itemId = '') {
        if (!this.isAvailable) {
            this._launchApp();
            return;
        }
        
        try {
            this._proxy.StartFocusSync(itemId);
        } catch (e) {
            console.error('Failed to start focus:', e);
        }
    }
    
    pauseFocus() {
        if (!this.isAvailable) return;
        
        try {
            this._proxy.PauseFocusSync();
        } catch (e) {
            console.error('Failed to pause focus:', e);
        }
    }
    
    resumeFocus() {
        if (!this.isAvailable) return;
        
        try {
            this._proxy.ResumeFocusSync();
        } catch (e) {
            console.error('Failed to resume focus:', e);
        }
    }
    
    stopFocus() {
        if (!this.isAvailable) return;
        
        try {
            this._proxy.StopFocusSync();
        } catch (e) {
            console.error('Failed to stop focus:', e);
        }
    }
    
    skipBreak() {
        if (!this.isAvailable) return;
        
        try {
            this._proxy.SkipBreakSync();
        } catch (e) {
            console.error('Failed to skip break:', e);
        }
    }
    
    completeFocusedTask() {
        if (!this.isAvailable) return;
        
        try {
            this._proxy.CompleteFocusedTaskSync();
        } catch (e) {
            console.error('Failed to complete focused task:', e);
        }
    }
    
    getNextSuggestedTask() {
        if (!this.isAvailable) return null;
        
        try {
            const [jsonString] = this._proxy.GetNextSuggestedTaskSync();
            if (jsonString && jsonString !== '{}') {
                return JSON.parse(jsonString);
            }
        } catch (e) {
            console.error('Failed to get next suggested task:', e);
        }
        
        return null;
    }
    
    _launchApp() {
        try {
            const appInfo = Gio.DesktopAppInfo.new('io.github.lab_gek.bluplan.desktop');
            if (appInfo) {
                appInfo.launch([], null);
            }
        } catch (e) {
            console.error('Failed to launch BluPlan:', e);
        }
    }
    
    // Signal management
    connect(signalName, callback) {
        if (!this._signals[signalName]) {
            this._signals[signalName] = [];
        }
        
        const id = this._signals[signalName].length;
        this._signals[signalName].push(callback);
        return id;
    }
    
    disconnect(signalName, id) {
        if (this._signals[signalName]) {
            delete this._signals[signalName][id];
        }
    }
    
    _emitSignal(signalName, ...args) {
        if (this._signals[signalName]) {
            this._signals[signalName].forEach(callback => {
                if (callback) callback(...args);
            });
        }
    }
    
    destroy() {
        if (this._nameWatcherId > 0) {
            Gio.bus_unwatch_name(this._nameWatcherId);
            this._nameWatcherId = 0;
        }
        
        this._proxy = null;
        this._signals = {};
    }
}
