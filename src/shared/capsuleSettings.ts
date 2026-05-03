// ─── Desktop Muse Capsule Settings ─────────────────────────────────
// Type definitions and default values for the Desktop Muse Capsule feature.
// See: PinMind_DesktopMuseCapsule_设计规范_v1.md §14

// ─── Theme Colors ───────────────────────────────────────────────

export type CapsuleThemeColor = 'orange' | 'green' | 'blue' | 'gray' | 'purple' | 'rose';

export const CAPSULE_THEME_COLORS: Record<CapsuleThemeColor, string> = {
  orange: '#FF6A1A',
  green: '#2FBF71',
  blue: '#3B82F6',
  gray: '#64748B',
  purple: '#8B5CF6',
  rose: '#F43F5E',
};

// ─── Capsule Style ──────────────────────────────────────────────

export type CapsuleStyle = 'capsule' | 'circle' | 'outline' | 'glass';

// ─── Capsule Size ───────────────────────────────────────────────

export type CapsuleSize = 'small' | 'medium' | 'large';

export const CAPSULE_SIZE_DIMS: Record<CapsuleSize, { width: number; height: number }> = {
  small: { width: 124, height: 52 },
  medium: { width: 138, height: 56 },
  large: { width: 152, height: 60 },
};

// ─── Default Position ───────────────────────────────────────────

export type CapsuleDefaultPosition =
  | 'right-center'
  | 'right-bottom'
  | 'left-center'
  | 'left-bottom'
  | 'bottom-center'
  | 'remember-last';

// ─── Dock Edge ──────────────────────────────────────────────────

export type DockEdge = 'left' | 'right' | 'bottom' | null;

// ─── Click / Double-Click / Hover Actions ───────────────────────

export type CapsuleClickAction = 'expand-panel' | 'capture-clipboard' | 'open-main-window';
export type CapsuleDoubleClickAction = 'quick-screenshot' | 'quick-text' | 'open-main-window' | 'none';
export type CapsuleHoverAction = 'peek-only' | 'expand-panel' | 'none';

// ─── Capture Type ───────────────────────────────────────────────

export type CapsuleCaptureType = 'text' | 'screenshot' | 'voice' | 'clipboard';

// ─── Default Action ─────────────────────────────────────────────

export type CapsuleDefaultAction = 'inbox' | 'ai-organize' | 'custom-flow';

// ─── Default Destination ────────────────────────────────────────

export type CapsuleDestination = 'pinmind-inbox' | 'obsidian-inbox' | 'project';

// ─── Capsule State Machine ──────────────────────────────────────

export type CapsuleState =
  | 'hidden_disabled'
  | 'visible_idle'
  | 'visible_has_content'
  | 'edge_hidden'
  | 'edge_peek'
  | 'expanded'
  | 'recording_voice'
  | 'capturing_screen'
  | 'saving'
  | 'success'
  | 'error';

// ─── DesktopMuseCapsuleSettings ─────────────────────────────────

export interface CapsulePlacementSettings {
  defaultPosition: CapsuleDefaultPosition;
  allowDrag: boolean;
  autoDockToEdge: boolean;
  edgeHidden: boolean;
  edgeVisibleWidth: 4 | 6 | 8 | 12;
  avoidSafeArea: boolean;
  lastPosition?: {
    screenId: string;
    x: number;
    y: number;
    dockedEdge?: DockEdge;
  };
}

export interface CapsuleInteractionSettings {
  clickAction: CapsuleClickAction;
  doubleClickAction: CapsuleDoubleClickAction;
  hoverAction: CapsuleHoverAction;
  hoverDelayMs: number;
  autoCollapseOnBlur: boolean;
  reduceOpacityWhenDragging: boolean;
}

export interface CapsuleQuickCaptureSettings {
  defaultCaptureType: CapsuleCaptureType;
  defaultAction: CapsuleDefaultAction;
  defaultDestination: CapsuleDestination;
  clearInputAfterCapture: boolean;
  showNotificationAfterCapture: boolean;
}

export interface CapsuleShortcutSettings {
  toggleCapsule: string;
  quickText: string;
  quickScreenshot: string;
  voiceInput: string;
  clipboardCapture: string;
}

export interface CapsuleNotificationSettings {
  captureSuccess: boolean;
  aiComplete: boolean;
  saveFailed: boolean;
  pendingReminder: boolean;
}

export interface DesktopMuseCapsuleSettings {
  enabled: boolean;
  startup: {
    showOnAppLaunch: boolean;
    showOnSystemStartup: boolean;
    autoWakeWhenEdgeHidden: boolean;
    showPendingCount: boolean;
  };
  appearance: {
    themeColor: CapsuleThemeColor;
    style: CapsuleStyle;
    opacity: number;
    size: CapsuleSize;
    adaptDarkMode: boolean;
  };
  placement: CapsulePlacementSettings;
  interaction: CapsuleInteractionSettings;
  quickCapture: CapsuleQuickCaptureSettings;
  shortcuts: CapsuleShortcutSettings;
  notifications: CapsuleNotificationSettings;
}

// ─── Default Values ─────────────────────────────────────────────

export const DEFAULT_CAPSULE_SETTINGS: DesktopMuseCapsuleSettings = {
  enabled: true,
  startup: {
    showOnAppLaunch: true,
    showOnSystemStartup: false,
    autoWakeWhenEdgeHidden: true,
    showPendingCount: true,
  },
  appearance: {
    themeColor: 'orange',
    style: 'capsule',
    opacity: 0.78,
    size: 'medium',
    adaptDarkMode: false,
  },
  placement: {
    defaultPosition: 'right-center',
    allowDrag: true,
    autoDockToEdge: true,
    edgeHidden: true,
    edgeVisibleWidth: 6,
    avoidSafeArea: true,
  },
  interaction: {
    clickAction: 'expand-panel',
    doubleClickAction: 'quick-screenshot',
    hoverAction: 'peek-only',
    hoverDelayMs: 200,
    autoCollapseOnBlur: true,
    reduceOpacityWhenDragging: true,
  },
  quickCapture: {
    defaultCaptureType: 'text',
    defaultAction: 'inbox',
    defaultDestination: 'pinmind-inbox',
    clearInputAfterCapture: true,
    showNotificationAfterCapture: true,
  },
  shortcuts: {
    toggleCapsule: 'Cmd+Shift+P',
    quickText: 'Cmd+Shift+T',
    quickScreenshot: 'Cmd+Shift+S',
    voiceInput: 'Cmd+Shift+V',
    clipboardCapture: 'Cmd+Shift+C',
  },
  notifications: {
    captureSuccess: true,
    aiComplete: true,
    saveFailed: true,
    pendingReminder: true,
  },
};

/**
 * Deep merge a partial capsule settings object with defaults.
 */
export function mergeCapsuleSettings(
  partial: Partial<DesktopMuseCapsuleSettings>,
): DesktopMuseCapsuleSettings {
  return {
    ...DEFAULT_CAPSULE_SETTINGS,
    ...partial,
    startup: { ...DEFAULT_CAPSULE_SETTINGS.startup, ...(partial.startup ?? {}) },
    appearance: { ...DEFAULT_CAPSULE_SETTINGS.appearance, ...(partial.appearance ?? {}) },
    placement: { ...DEFAULT_CAPSULE_SETTINGS.placement, ...(partial.placement ?? {}) },
    interaction: { ...DEFAULT_CAPSULE_SETTINGS.interaction, ...(partial.interaction ?? {}) },
    quickCapture: { ...DEFAULT_CAPSULE_SETTINGS.quickCapture, ...(partial.quickCapture ?? {}) },
    shortcuts: { ...DEFAULT_CAPSULE_SETTINGS.shortcuts, ...(partial.shortcuts ?? {}) },
    notifications: { ...DEFAULT_CAPSULE_SETTINGS.notifications, ...(partial.notifications ?? {}) },
  };
}
