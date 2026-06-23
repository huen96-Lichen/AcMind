# Roadmap

## Current stabilization

- Reconcile stale layout and snapshot tests with the current UI source of truth.
- Keep the known-failure baseline visible and documented until those tests are updated or retired.
- Preserve clean-clone build reproducibility.
- Keep helper installation, code signing, and bundle layout documentation aligned with the actual build path.

## Near-term

- Improve privacy and permission onboarding for microphone, accessibility, screen recording, clipboard, and input monitoring paths.
- Tighten the local and cloud data-flow documentation.
- Improve the contributor experience for source-only changes, especially clean-clone validation.
- Continue making AcMindKit easier to reuse as a standalone service layer.

## Later exploration

- Verify Intel support or document where support stops.
- Improve helper signing and installation behavior for release packaging.
- Revisit release packaging so it is predictable on machines without release credentials.
- Expand public docs where the codebase needs a clearer explanation of ownership, state, and data flow.

## Non-goals for the current phase

- Promise dates.
- Claim full release stability before the known failures are resolved.
- Rewrite Git history.
- Change application behavior just to simplify documentation.
- Remove vendored dependencies or archival design assets without a separate review.
