# Security Policy

## Supported status

AcMind is currently pre-release. Security review should focus on the current `main` branch and the upcoming `v0.1.0-alpha` release line.

Older snapshots are not guaranteed to receive security fixes.

## Reporting a vulnerability

Use GitHub private vulnerability reporting if it is enabled for this repository. That is the preferred path for:

- API key exposure;
- local file disclosure;
- clipboard leakage;
- screen content leakage;
- microphone or accessibility permission misuse;
- input monitoring concerns;
- helper installation or privilege-boundary issues;
- cloud-provider data leaks;
- insecure packaging or update behavior.

If the repository does not yet expose GitHub private vulnerability reporting, maintainers need to enable it before public release. Do not publish exploit details, proof-of-concept code, screenshots with sensitive content, or credentials in a public issue.

## What to include in a private report

- a short summary;
- how to reproduce the issue;
- the affected feature or path;
- the expected and actual behavior;
- relevant macOS, Xcode, and Swift versions;
- any commit or release identifier involved;
- whether the issue is a regression;
- whether the data exposure is local-only or can leave the device.

## What not to include publicly

Do not post:

- secrets or tokens;
- private URLs or credentials;
- clipboard contents;
- screenshots with personal data;
- local machine paths that identify a workstation;
- exploit payloads or bypass instructions.

## Acknowledgement

We aim to acknowledge private reports promptly and keep the discussion private while the issue is being reviewed.

We cannot promise a fixed response time or a formal audit result, because no formal security audit has been completed for this repository.

## Current limitations

Known limitations that still need careful review before release include:

- local secret storage can fall back to plaintext settings storage when that preference is selected;
- cloud providers receive whatever data the user explicitly routes to them;
- permission-dependent features rely on macOS privacy prompts and user consent;
- helper installation and code-signing behavior should be validated carefully on new machines;
- telemetry has not been identified as a dedicated product pipeline, but the codebase should be re-audited before claiming that no data ever leaves the device.
