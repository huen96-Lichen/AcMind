# Privacy and Permissions

This document records the permissions and data-handling surfaces that are visible in the current repository. Where a behavior is not fully confirmed by code audit, it is marked as needing review.

## Permission surfaces

| Surface | Status | What it is used for | Notes |
|---|---|---|---|
| Microphone | Verified | Voice input and recording workflows | The app requests microphone access for voice features. |
| Accessibility | Verified | Text insertion and system interaction | Used by capture and input-assistance flows. |
| Screen Recording | Verified | Screenshot and capture workflows | Required when the app captures screen content. |
| Clipboard | Verified | Clipboard collection and pinning | Clipboard data may be read, stored locally, and displayed in the app. |
| File access | Verified | Export, local notes, document processing, and vault integration | Some workflows touch local files and user-selected storage locations. |
| Notifications | Verified | In-app and system feedback | Used for user-visible state changes and alerts. |
| Global input monitoring | Needs code audit | Hotkey and input-related features may rely on system input hooks | Confirm the exact permission path before release notes claim more. |
| Full Disk Access | Needs code audit | Broad file-heavy workflows may benefit from it | The repository mentions it in the README, but the exact dependency should be audited before release claims. |

## Local storage

The repository includes local storage for:

- application settings;
- workspace state;
- clipboard and capture data;
- export and cache artifacts;
- local helper and service state.

The codebase also includes a local secret store for provider credentials.

## API key storage

API credentials are stored locally. The implementation supports Keychain-backed storage and also contains a plaintext fallback in local settings when the corresponding preference is selected.

That fallback is a security-sensitive tradeoff and should stay documented clearly in the release notes and security policy.

## Local model use

The project includes local-provider routing, including paths that can be used with local model backends.

When a local model is selected, the payload should remain on device except for any local logs or artifacts the user chooses to export.

## Cloud model use

Cloud-backed features can send user-selected content to external providers.

What may leave the device depends on the workflow the user explicitly chooses. That can include prompts, transcripts, screenshots, files, or other capture output that is routed to a provider.

## Telemetry policy

No dedicated product telemetry pipeline was identified in the current audit.

That does not mean the codebase is fully audited for every log destination. Before release, re-check:

- OS log output;
- crash reports;
- helper logs;
- provider SDK behavior;
- any future analytics or diagnostics integrations.

## Revoking permissions

Users can revoke macOS permissions from System Settings under Privacy & Security:

- Microphone
- Accessibility
- Screen Recording
- Input Monitoring
- Full Disk Access
- Notifications

If a permission is revoked, the affected feature should be expected to degrade or stop working until access is restored.

## Deleting local data

The repository currently stores data locally. To remove it, users should clear the app's local storage, settings, caches, and any Keychain entries created for provider credentials.

This document does not claim that the app already exposes a single, audited "delete all data" flow. That should be verified in code before such a promise is added to public documentation.

## Data that may leave the device

Only user-chosen workflows should send data off device.

Possible outbound data includes:

- AI prompts;
- voice transcripts;
- screenshots or captured windows;
- files sent to a cloud provider;
- metadata required by a remote service.

If you are adding a new workflow, document the outbound payload explicitly before release.
