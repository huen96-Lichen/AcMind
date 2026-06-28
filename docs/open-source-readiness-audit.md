# AcMind Open Source Readiness Audit

Date: 2026-06-24
Scope: tracked repository contents and Git history, with repo-owned files reviewed separately from vendored third-party sources.

## Summary

I found no obvious repo-owned API keys, access tokens, private key material, Apple signing certificates, or GitHub-style secret tokens in the tracked tree or history using the scan patterns I ran.

The main open-source readiness risk is not credential leakage. It is that the repository still contains many workstation-specific absolute filesystem paths in public-facing docs and some developer/debug code, which makes the project look less reproducible and less polished than it should.

## Findings

| ID | Severity | Finding | Evidence | Proposed remediation |
|---|---|---|---|---|
| OSR-001 | High | Public documentation and committed history contain workstation-specific absolute paths. These break GitHub links, expose local machine details, and make the repo look non-reproducible. | `README.md:150-151`; `docs/acmind-handoff-2026-06-05.md:24-28, 44-48, 58-60, 76-79`; `docs/acmind-handoff-2026-06-06.md:40-54, 71, 76-100`; `docs/Bento_Visual_Unification_Task.md:15-16, 40, 48, 55, 62, 69, 80, 88, 95, 102, 109, 116, 128-152, 163-167, 174, 186-200, 211-223, 235-236`; `docs/audit/AcWork_Workbench_Current_Layout.md:9-11, 49, 75-82`; `docs/audit/AcWork_Workbench_Component_Map.md:9-26, 37-41`; `docs/refactor/workbench-v17/WorkbenchV17_BackgroundPersistence.txt:3-4`; Git history contains the same path-heavy docs and notes. | Replace every local absolute path with a repo-relative link or a generic placeholder such as `path/to/file.swift`. Keep any local-only notes out of the public tree, or move them into a private scratch area that is not committed. |
| OSR-002 | Medium | Developer/debug code in `App/AppDelegate.swift` hard-codes workstation-specific export directories and a local background image path. That is fragile on other machines and leaks local filesystem layout into shipped source. | `App/AppDelegate.swift:550-552, 718-720, 889-892, 1096-1104, 1298-1305`. | Parameterize output directories through `FileManager` temporary/application-support locations, CLI flags, or environment variables. Keep these helpers behind debug-only code paths if they are only for local audits. Replace the hard-coded background source with a repo-relative sample asset or a test fixture. |
| OSR-003 | Low | The repository tracked build-directory files under `build/` even though `.gitignore` treats `build/` as generated output. This blurred the line between source and generated artifacts. | `.gitignore:4-10`; previously tracked files `build/entitlements.mac.plist` and `build/entitlements.mac.inherit.plist`. | Move any source-controlled signing or entitlement templates into a clearly named source folder, or add explicit `.gitignore` exceptions and document why those files are versioned. |

## Remediation status

| Finding | Status | Changes | Validation |
|---|---|---|---|
| OSR-001 | Partially remediated | Replaced repo-owned absolute documentation links with relative paths where they were in the current tree; moved runtime debug export paths to temporary directories; kept the historical path record intact as requested. | Remaining history references are documented only; no history rewrite was performed. |
| OSR-002 | Remediated | Removed workstation-specific export directories and the local background image path from `App/AppDelegate.swift`. The code now writes audit exports to the temporary directory and uses a repo fixture path for the sample background. | Portable path helpers are in place; follow-up build validation is still required. |
| OSR-003 | Remediated | Moved entitlements into `Config/Entitlements/` and removed the tracked files from `build/`. | `git status` now shows the source-controlled entitlements under `Config/Entitlements/` instead of `build/`. |

## Non-issues confirmed

- No repo-owned secret-like tokens matched the scan patterns I used for `ghp_`, `github_pat_`, `xoxb-`, `sk-`, `AKIA`, `AIza`, or PEM private key headers.
- No repo-owned `.env`, `xcuserdata`, `DerivedData`, `.xcresult`, `.ipa`, `.dSYM`, or similar build-output directories were tracked.
- Vendored third-party code does contain author emails and example email addresses, but those appear to be upstream provenance and documentation examples rather than AcMind-specific leakage.

## Remediation priority

1. Remove or rewrite all absolute path references in public docs.
2. Convert debug/export helpers to portable paths.
3. Separate tracked source files from generated build artifacts.

## Notes

I intentionally did not rewrite Git history or make any behavior-changing edits as part of this audit-only checkpoint.

Historical absolute paths are considered low-sensitivity workstation metadata. They will not be removed from Git history unless a stronger privacy requirement is identified.
