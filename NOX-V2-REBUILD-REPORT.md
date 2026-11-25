# NOX V2 Safe UI Rebuild (based on 3106)

## Changes in this package
- Preserved the V2/3106 Xcode project and its source tree as the technical base.
- Replaced the top-level navigation with exactly four tabs: HOME, PATCH, ADMIN, INFO.
- Applied a Dark Premium palette (deep navy/black, cyan/blue accents, gold status).
- Added NOX V2 display branding while retaining internal project/scheme/product identifiers for compatibility.
- Added translated UI strings for Vietnamese, English, Simplified Chinese and Korean.
- PATCH tab is read-only package inventory; it does not execute patch payloads.
- Key Server status is explicitly unconfigured. No fake activation, server success, or license state is shown.
- Changed GitHub Actions runner from macos-15 ARM64 to macos-15-intel to avoid the runner-capacity failure shown in the user's Actions logs.
- Retained existing source, dependency and legal files rather than deleting unreferenced modules without dependency analysis.

## Verification performed
- ZIP structure inspected.
- Static source checks and policy tests are run in this environment (see build report).
- Xcode build is not available here because this environment is not macOS. IPA compilation, signing, installation and device runtime remain unverified.

## Safety/functional boundary
This rebuild focuses on navigation, UI, branding, localization, source preservation, and reproducible CI. Kernel exploit execution, sandbox escapes, anti-detection, security bypasses, and applying device/system patches are not wired into the new UI. License/key-server integration is not connected because a verified backend endpoint and API schema are not supplied in this package.
