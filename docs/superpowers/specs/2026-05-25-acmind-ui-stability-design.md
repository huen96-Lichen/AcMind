# AcMind UI Stability Design

## Goal

Fix the current UI regression so the app consistently presents the latest 0.0.4-style experience and does not drift back into the older gray/Agent-heavy layout.

The fix must address four visible issues:

1. Eliminate the unintended gray content areas in the main UI.
2. Restore the interaction between the desktop capsule and the dynamic continent so dragging the capsule to the top of the screen snaps it into the continent state.
3. Improve first-level menu readability so labels are not clipped and remain legible.
4. Restore the status section in the expanded dynamic continent view.

Stability is a hard requirement. The implementation should minimize structural churn and reuse existing views and state where possible.

## Current Diagnosis

- The gray appearance is coming from a mix of old surface tokens, legacy split-view styling, and a few dark placeholder panels inside the companion views.
- The capsule and the continent are currently independent windows with no explicit snap/attach coordinator.
- The main sidebar still uses compact row geometry that clips text in narrow layouts.
- The expanded continent page shows content panels, but the status block that users expect is not always present in the expanded layout.

## Proposed Approach

### 1. Visual surface normalization

Standardize the main window and sidebar surfaces on a lighter card-based palette:

- Replace gray fills that are only acting as background chrome.
- Keep white or near-white surfaces for the main working area.
- Reserve darker tones only for intentional companion components that are part of the notch-style visual language.

This keeps the app visually closer to the new design while avoiding a risky full redesign.

### 2. Capsule-to-continent snap coordinator

Introduce a small shared docking decision path between the capsule window and the continent window:

- The capsule tracks drag position.
- When its top edge enters a configurable snap zone near the screen top, it requests the continent to expand.
- The continent becomes the visible state and the capsule collapses or hides.

This should be implemented as a focused coordinator or shared state object rather than by coupling the two window classes tightly.

### 3. Sidebar layout hardening

Adjust the primary menu rows so labels have enough width and can scale gracefully:

- Increase label room in the row layout.
- Add truncation protection and minimum scale behavior.
- Keep icons and shortcuts aligned without compressing the label into unreadable fragments.

### 4. Restored expanded status block

Ensure the expanded dynamic continent includes the status section as a first-class part of the overview page:

- Reuse the existing status cards and status line components already present in the companion views.
- Place the status block in a predictable position in the expanded hierarchy.
- Keep the block lightweight so it does not add layout instability.

## Components to Touch

- `App/ContentView.swift`
- `App/SidebarItem.swift`
- `App/AppState.swift`
- `Features/Companion/NotchPanel.swift`
- `Features/Companion/NotchV2TopBar.swift`
- `Features/Companion/NotchV2OverviewPage.swift`
- `Features/Native/DesktopCapsule/DesktopCapsulePanel.swift`
- `Features/Native/DesktopCapsule/DesktopCapsuleViewModel.swift`
- `Features/Native/Shared/AppSurfaceStyle.swift`

## Data and State Flow

1. The app launches into the latest main workspace and selects the new default entry instead of the old Agent-first state.
2. The capsule window continues to own its own presentation state while reporting drag position to a shared docking decision path.
3. When the docking threshold is crossed, the shared path requests the continent window to show and expand.
4. The expanded continent renders the overview page with the status block included.

## Error Handling and Stability

- Keep the docking threshold logic defensive so accidental pointer movement does not trigger repeated attach/detach loops.
- Preserve the existing window show/hide APIs so the app still launches and recovers normally if docking fails.
- Avoid introducing new global singletons unless they are strictly for window coordination and can be reused by both windows.
- If any subview fails to render its optional content, it should fall back to an empty-but-stable card rather than a broken layout.

## Verification

We will consider the fix complete only if all of the following are true:

- The main window no longer shows the unintended gray side panels in the default path.
- Sidebar labels remain legible and are not visibly clipped.
- Dragging the capsule toward the top of the screen snaps into the continent state.
- The expanded continent shows the status section again.
- The project builds successfully after the change.

## Testing Plan

- Run a clean `xcodebuild` build for the main scheme.
- Launch the app and verify the default entry point.
- Visually inspect:
  - the main sidebar
  - the capsule drag-to-top behavior
  - the expanded continent status section
- Check that no new console warnings or layout assertions are introduced during the interaction.

