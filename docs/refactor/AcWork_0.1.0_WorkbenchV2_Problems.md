# AcWork 0.1.0 WorkbenchV2 Problems

This file records the current implementation risks and places that still need HTML prototype confirmation.

## Resolved During Scaffolding

- Legacy `WorkspaceHomeView` remains intact.
- V2 is behind a debug-time toggle on the main home route.
- Root layout no longer depends on a vertical `ScrollView`.
- Debug overlay is `DEBUG` only.
- V2 export produces runtime frames and screenshots.

## Still Provisional

- Final visual language is not implemented yet.
- Most token values are fixed scaffold values and may change after the HTML prototype lands.
- The preview chart values are still fixed sample data.
- Compact layout rules are functional but intentionally conservative.

## Notes From Runtime Export

- Default canvas exports at `1500 × 888`.
- Compact export runs at `1180 × 720`.
- The page is fully non-scrolling at the default size.
- The chart and card heights are still tuned for structure, not final design.
