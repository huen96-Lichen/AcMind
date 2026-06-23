# Repository Size Audit

Date: 2026-06-24

This audit identifies the largest tracked files and gives conservative cleanup recommendations. It does not change repository history.

## Largest tracked files

The largest tracked files currently include:

| Path | Approx. size | Category | Recommendation |
|---|---:|---|---|
| `Vendor/stats-original/Stats/Supporting Files/popups.psd` | 15.9 MB | Design source asset | Keep only if the vendor bundle needs it. Otherwise prefer an external archive or Git LFS. |
| `Vendor/LottieSwiftUI/Tests/Samples/Issues/issue_1403.json` | 8.9 MB | Vendor test fixture | Keep as part of the vendored dependency unless upstream removes the need. |
| `Vendor/GRDB.swift/Tests/Performance/GRDBProfiling/GRDBProfiling/ProfilingDatabase.sqlite` | 4.4 MB | Vendor performance fixture | Keep in vendor scope or move to LFS only if the vendor mirror is being slimmed. |
| `Vendor/LottieSwiftUI/_AeFiles/LottieLogos.aep` | 2.8 MB | Design source asset | Candidate for LFS or external archival storage if not required for normal builds. |
| `docs/screenshots/companion-unification/companion-six-pages-contact-sheet.png` | 2.5 MB | Documentation asset | Keep if it is actively referenced; otherwise regenerate at a smaller size. |
| `Vendor/LottieSwiftUI/Tests/__Snapshots__/SnapshotTests/*.png` | 2.0 to 2.4 MB each | Vendor snapshot data | Keep only if the vendored test suite still depends on them. If the vendor package is ever unbundled, move heavy snapshots to LFS. |
| `docs/refactor/workbench-v17/html-vs-swiftui-1500x888.png` | 2.3 MB | Documentation comparison image | Keep if still referenced by the refactor docs. |
| `docs/refactor/workbench-v17/screenshots/*.png` | 1.5 MB+ | Documentation evidence | Keep unless the documentation is being compressed into a lighter archive. |
| `615设计规范/AcWork_Codex_UI_Redesign_Task.zip` | 1.3 MB | Archival handoff artifact | Better suited to GitHub Releases or external archival storage if it is no longer part of day-to-day documentation. |

## Generated files and binary assets

The repository contains a mix of generated docs artifacts, screenshots, archives, and vendored binary test fixtures.

The following classes are the main size drivers:

- large PNG screenshots used for design evidence;
- GIFs and other animation assets in vendored packages;
- PSD and AEP source files for design work;
- database and snapshot fixtures under vendored dependency trees;
- archived task bundles and handoff material.

## .gitignore review

The root `.gitignore` already covers the main local-noise categories:

- build products and derived artifacts;
- `.build/` and `build/`;
- `xcuserdata/`;
- local logs and runtime data;
- local assistant and tool state;
- OS and editor files;
- temporary files;
- local vault and reference-only source folders.

No tracked `.env`, `DerivedData`, or `xcuserdata` paths were identified in this checkpoint.

## Cleanup recommendations

### Safe to delete when encountered locally

- generated editor caches such as `.DS_Store`;
- local build output directories;
- ad hoc log files;
- temporary session artifacts;
- local assistant state directories that are not part of the repository.

### Candidate for GitHub Releases or external archive storage

- `615设计规范/AcWork_Codex_UI_Redesign_Task.zip`
- any future handoff archive that exists only as a release artifact

### Candidate for Git LFS

- large PSD or AEP source files if they continue to grow or are edited regularly;
- large screenshot sets if the repository begins to treat them as mutable assets rather than documentation evidence;
- large binary fixtures that are not required in a plain Git clone.

### Leave in the repository for now

- vendored dependency source trees;
- snapshot assets needed by the vendor test suites;
- documentation screenshots that are part of the public evidence trail.

No repository history rewrite was performed for this audit.
