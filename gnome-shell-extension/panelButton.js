/* panelButton.js
 *
 * Panel button UI for displaying BluPlan focus state in top bar
 */

import Clutter from 'gi://Clutter';
import GObject from 'gi://GObject';
import St from 'gi://St';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';

export const BluPlanPanelButton = GObject.registerClass(
class BluPlanPanelButton extends PanelMenu.Button {
    _init(dbusClient, settingsManager) {
        super._init(0.0, 'BluPlan Focus', false);
        
        this._dbusClient = dbusClient;
        this._settings = settingsManager;
        
        this._currentState = null;
        this._nextTask = null;
        
        // Create panel button content
        this._createPanelContent();
        
        // Create popup menu
        this._createMenu();
        
        // Connect to DBus signals
        this._connectSignals();
        
        // Initial state update
        this._updateState();
        
        // Connect to settings changes
        this._settings.connect('view-mode', () => this._rebuildUI());
        this._settings.connect('show-timer', () => this._rebuildUI());
        this._settings.connect('show-task-name', () => this._rebuildUI());
    }
    
    _createPanelContent() {
        const box = new St.BoxLayout({
            style_class: 'panel-status-menu-box bluplan-focus-panel'
        });
        
        // State icon
        this._stateIcon = new St.Icon({
            icon_name: 'media-playback-pause-symbolic',
            style_class: 'system-status-icon'
        });
        box.add_child(this._stateIcon);
        
        // Timer label
        this._timerLabel = new St.Label({
            text: '--:--',
            y_align: Clutter.ActorAlign.CENTER,
            style_class: 'bluplan-timer-label'
        });
        
        if (this._settings.showTimer) {
            box.add_child(this._timerLabel);
        }
        
        this.add_child(box);
        this._panelBox = box;
    }
    
    _createMenu() {
        // Current task section
        this._taskLabel = new St.Label({
            text: 'No task selected',
            style_class: 'bluplan-task-label'
        });
        
        const taskItem = new PopupMenu.PopupBaseMenuItem({
            reactive: true,
            can_focus: true
        });
        taskItem.add_child(this._taskLabel);
        taskItem.connect('activate', () => {
            this._dbusClient._launchApp();
            this.menu.close();
        });
        
        this.menu.addMenuItem(taskItem);
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        
        // Control buttons section
        const controlsBox = new St.BoxLayout({
            style_class: 'bluplan-controls-box',
            x_expand: true
        });
        
        // Start/Pause button
        this._startPauseButton = new St.Button({
            style_class: 'button bluplan-control-button',
            can_focus: true,
            x_expand: true
        });
        this._startPauseIcon = new St.Icon({
            icon_name: 'media-playback-start-symbolic',
            icon_size: 16
        });
        this._startPauseButton.set_child(this._startPauseIcon);
        this._startPauseButton.connect('clicked', () => this._onStartPauseClicked());
        controlsBox.add_child(this._startPauseButton);
        
        // Stop button
        this._stopButton = new St.Button({
            style_class: 'button bluplan-control-button',
            can_focus: true,
            x_expand: true
        });
        const stopIcon = new St.Icon({
            icon_name: 'media-playback-stop-symbolic',
            icon_size: 16
        });
        this._stopButton.set_child(stopIcon);
        this._stopButton.connect('clicked', () => this._onStopClicked());
        controlsBox.add_child(this._stopButton);
        
        // Complete button
        this._completeButton = new St.Button({
            style_class: 'button bluplan-control-button',
            can_focus: true,
            x_expand: true
        });
        const completeIcon = new St.Icon({
            icon_name: 'object-select-symbolic',
            icon_size: 16
        });
        this._completeButton.set_child(completeIcon);
        this._completeButton.connect('clicked', () => this._onCompleteClicked());
        controlsBox.add_child(this._completeButton);
        
        const controlsItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false
        });
        controlsItem.add_child(controlsBox);
        
        if (this._settings.showControls) {
            this.menu.addMenuItem(controlsItem);
        }
        this._controlsMenuItem = controlsItem;
        
        // Next task section
        if (this._settings.showNextTask) {
            this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
            
            const nextTaskLabel = new St.Label({
                text: 'Next Task',
                style_class: 'bluplan-section-label'
            });
            const nextTaskLabelItem = new PopupMenu.PopupBaseMenuItem({
                reactive: false,
                can_focus: false
            });
            nextTaskLabelItem.add_child(nextTaskLabel);
            this.menu.addMenuItem(nextTaskLabelItem);
            
            this._nextTaskLabel = new St.Label({
                text: 'Loading...',
                style_class: 'bluplan-next-task-label'
            });
            const nextTaskItem = new PopupMenu.PopupBaseMenuItem({
                reactive: true,
                can_focus: true
            });
            nextTaskItem.add_child(this._nextTaskLabel);
            nextTaskItem.connect('activate', () => {
                if (this._nextTask) {
                    this._dbusClient.startFocus(this._nextTask.id);
                }
                this.menu.close();
            });
            this.menu.addMenuItem(nextTaskItem);
            this._nextTaskMenuItem = nextTaskItem;
            
            // Load next task
            this._updateNextTask();
        }
        
        // Availability indicator
        this.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        this._statusLabel = new St.Label({
            text: 'Connecting...',
            style_class: 'bluplan-status-label'
        });
        const statusItem = new PopupMenu.PopupBaseMenuItem({
            reactive: false,
            can_focus: false
        });
        statusItem.add_child(this._statusLabel);
        this.menu.addMenuItem(statusItem);
    }
    
    _rebuildUI() {
        // Rebuild panel content
        this._panelBox.destroy_all_children();
        
        this._stateIcon = new St.Icon({
            icon_name: this._getStateIcon(),
            style_class: 'system-status-icon'
        });
        this._panelBox.add_child(this._stateIcon);
        
        if (this._settings.showTimer) {
            this._timerLabel = new St.Label({
                text: this._formatTime(this._currentState?.secondsRemaining || 0),
                y_align: Clutter.ActorAlign.CENTER,
                style_class: 'bluplan-timer-label'
            });
            this._panelBox.add_child(this._timerLabel);
        }
        
        if (this._settings.showTaskName && this._currentState?.focusedItemContent) {
            const taskLabel = new St.Label({
                text: this._truncateText(this._currentState.focusedItemContent, 30),
                y_align: Clutter.ActorAlign.CENTER,
                style_class: 'bluplan-panel-task-label'
            });
            this._panelBox.add_child(taskLabel);
        }
    }
    
    _connectSignals() {
        this._dbusClient.connect('availability-changed', (available) => {
            this._onAvailabilityChanged(available);
        });
        
        this._dbusClient.connect('focus-state-changed', (data) => {
            this._updateState();
        });
        
        this._dbusClient.connect('timer-tick', (seconds) => {
            if (this._currentState) {
                this._currentState.secondsRemaining = seconds;
                this._updateTimerDisplay();
            }
        });
        
        this._dbusClient.connect('focused-task-changed', (data) => {
            this._updateState();
        });
        
        // Update next task when menu opens
        this.menu.connect('open-state-changed', (menu, open) => {
            if (open && this._settings.showNextTask) {
                this._updateNextTask();
            }
        });
    }
    
    _updateState() {
        this._currentState = this._dbusClient.getState();
        
        if (this._currentState) {
            this._updateIcon();
            this._updateTimerDisplay();
            this._updateTaskDisplay();
            this._updateControls();
        }
    }
    
    _updateIcon() {
        if (!this._currentState) return;
        
        const iconName = this._getStateIcon();
        this._stateIcon.icon_name = iconName;
    }
    
    _getStateIcon() {
        if (!this._currentState) {
            return 'media-playback-pause-symbolic';
        }
        
        if (this._currentState.state === 'working') {
            return this._currentState.running ? 'alarm-symbolic' : 'media-playback-pause-symbolic';
        } else if (this._currentState.state === 'short_break' || this._currentState.state === 'long_break') {
            return 'emblem-ok-symbolic';
        }
        
        return 'media-playback-pause-symbolic';
    }
    
    _updateTimerDisplay() {
        if (!this._currentState) return;
        
        const timeText = this._formatTime(this._currentState.secondsRemaining);
        
        if (this._timerLabel) {
            this._timerLabel.text = timeText;
        }
    }
    
    _formatTime(seconds) {
        const mins = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    
    _updateTaskDisplay() {
        if (!this._currentState) return;
        
        if (this._currentState.focusedItemContent) {
            const stateLabel = this._getStateLabel();
            this._taskLabel.text = `${stateLabel}: ${this._currentState.focusedItemContent}`;
        } else {
            this._taskLabel.text = 'No task selected';
        }
        
        if (this._settings.showTaskName) {
            this._rebuildUI();
        }
    }
    
    _getStateLabel() {
        if (!this._currentState) return 'Idle';
        
        switch (this._currentState.state) {
            case 'working':
                return 'Working';
            case 'short_break':
                return 'Short Break';
            case 'long_break':
                return 'Long Break';
            default:
                return 'Idle';
        }
    }
    
    _updateControls() {
        if (!this._currentState) return;
        
        const isIdle = this._currentState.state === 'idle';
        const isRunning = this._currentState.running;
        const isBreak = this._currentState.state === 'short_break' || 
                        this._currentState.state === 'long_break';
        
        // Update start/pause button
        if (isIdle || !isRunning) {
            this._startPauseIcon.icon_name = 'media-playback-start-symbolic';
        } else {
            this._startPauseIcon.icon_name = 'media-playback-pause-symbolic';
        }
        
        this._stopButton.visible = !isIdle;
        this._completeButton.visible = this._currentState.focusedItemContent !== '';
    }
    
    _updateNextTask() {
        this._nextTask = this._dbusClient.getNextSuggestedTask();
        
        if (this._nextTaskLabel) {
            if (this._nextTask && this._nextTask.content) {
                this._nextTaskLabel.text = this._nextTask.content;
            } else {
                this._nextTaskLabel.text = 'No tasks scheduled';
            }
        }
    }
    
    _truncateText(text, maxLength) {
        if (text.length <= maxLength) return text;
        return text.substring(0, maxLength - 3) + '...';
    }
    
    _onAvailabilityChanged(available) {
        if (this._statusLabel) {
            this._statusLabel.text = available ? 'Connected to BluPlan' : 'BluPlan not running';
        }
        
        if (available) {
            this._updateState();
        }
    }
    
    _onStartPauseClicked() {
        if (!this._currentState) return;
        
        if (this._currentState.state === 'idle') {
            this._dbusClient.startFocus('');
        } else if (this._currentState.running) {
            this._dbusClient.pauseFocus();
        } else {
            this._dbusClient.resumeFocus();
        }
        this._updateState();
    }
    
    _onStopClicked() {
        this._dbusClient.stopFocus();
        this._updateState();
    }
    
    _onCompleteClicked() {
        this._dbusClient.completeFocusedTask();
        this._updateState();
        this.menu.close();
    }
    
    destroy() {
        super.destroy();
    }
});
