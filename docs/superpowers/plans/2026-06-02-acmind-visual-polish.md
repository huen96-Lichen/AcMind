# AcMind Visual Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give AcMind a cohesive control-center visual system, with a flagship Notch/Companion treatment and a unified global surface language.

**Architecture:** Introduce a richer shared backdrop and surface token layer first, then restyle the flagship Notch/Companion surfaces to match the new system-dashboard direction. Apply the same baseline to the main shell so the whole app feels like one product.

**Tech Stack:** SwiftUI, existing app surface tokens, existing Notch design tokens, existing vendor libraries for later animation/popup integration.

---

### Task 1: Shared Visual Baseline

**Files:**
- Modify: `Features/Native/Shared/AppSurfaceStyle.swift`
- Modify: `App/ContentView.swift`
- Modify: `Features/Native/Tools/ToolsView.swift`

- [ ] **Step 1: Add the shared backdrop and surface token upgrades**
- [ ] **Step 2: Apply the new backdrop to the app shell**
- [ ] **Step 3: Refresh the tools page cards and background to match the new baseline**
- [ ] **Step 4: Build and verify the app still compiles**

### Task 2: Flagship Notch/Companion Treatment

**Files:**
- Modify: `Features/Companion/NotchV2DesignTokens.swift`
- Modify: `Features/Companion/NotchV2RootView.swift`
- Modify: `Features/Companion/NotchV2CollapsedView.swift`
- Modify: `Features/Companion/NotchV2ExpandedView.swift`
- Modify: `Features/Companion/NotchV2OverviewPage.swift`

- [ ] **Step 1: Rework the Notch palette and panel geometry**
- [ ] **Step 2: Add a stronger dashboard-style background treatment**
- [ ] **Step 3: Tighten the collapsed and expanded states**
- [ ] **Step 4: Build and verify the flagship view still compiles**

### Task 3: High-Frequency Pages

**Files:**
- Modify: `Features/Native/Settings/SettingsSuiteView.swift`
- Modify: `Features/Native/Settings/SettingsView.swift`
- Modify: `Features/Native/Agent/AgentDashboardView.swift`
- Modify: `Features/Native/SystemStatus/SystemStatusView.swift`

- [ ] **Step 1: Align high-frequency pages with the new surface language**
- [ ] **Step 2: Improve card hierarchy, spacing, and empty-state presentation**
- [ ] **Step 3: Rebuild and verify the changed screens compile**

