# Contributing to AcMind

AcMind is still pre-release. Contributions are welcome, but the project should be treated as an actively evolving macOS workspace rather than a finished public product.

If you plan a larger change, open an issue first so the scope, implementation path, and documentation impact can be agreed before code lands.

## Contribution workflow

Issue
→ branch
→ implementation
→ local validation
→ pull request
→ review

Please keep changes focused. Small, reviewable pull requests are much easier to validate than broad refactors that mix behavior, docs, and cleanup.

## Clean-clone setup

From a fresh clone, use the verified baseline commands recorded in `docs/testing-and-build-baseline.md`:

```bash
swift package reset
swift package resolve
swift build
swift test
```

To validate the app bundle with Xcode, use:

```bash
xcodebuild \
  -project AcMind.xcodeproj \
  -scheme AcMind \
  -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build
```

The portable app path is derived from Xcode build settings, not from `.build/debug/AcMind.app`.

## Known test baseline

`docs/testing-and-build-baseline.md` records the current baseline. At the time of writing, `swift test` still reports documented known failures across multiple suites, including `ToolWorkspaceStateTests` and other documented suites, so the full test workflow should remain visibly failing until those suites are updated.

Do not hide those failures, skip them silently, or introduce new unexplained failures. If your change affects a failing test or the expected surface text, update the baseline document in the same change.

## Code style and documentation

- Keep code changes narrowly scoped.
- Follow the existing Swift style and naming patterns in the repository.
- Do not commit personal data, credentials, screenshots with private content, or machine-specific absolute paths.
- If behavior changes, update the relevant documentation in the same pull request.
- If a UI surface changes, include updated screenshots or explain why they are not needed.
- Treat comments, docs, and README files as part of the change, not an afterthought.

## Validation expectations

Before opening a pull request, run the verified commands that apply to your change and record the results in the PR description.

At minimum, confirm the commands relevant to your work from `docs/testing-and-build-baseline.md`. For app-facing changes, include the Xcode build command. For source-only changes, at least confirm Swift package resolution and build.

Normal source contributions do not require Developer ID credentials, notarization credentials, or other release-only signing material.

## Pull request process

- Link the issue, if one exists.
- Summarize what changed and why.
- List the commands you ran.
- Call out any remaining known failures or limitations.
- Mention documentation or screenshot updates explicitly when they are part of the change.
