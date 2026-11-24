# NOX V2 — complete source package

This package is based on the supplied NOX V1 source as the UI/navigation/feature baseline, with the product identity set to NOX V2. It is not a merge of all 3106 screens.

## Navigation contract
Exactly four main tabs: HOME, PATCH, ADMIN, INFO. Settings, Logs, Patch Projects and License Information remain child screens opened from ADMIN. No extra standalone 3106 tabs are added.

## Included
- Complete NOX V1 source tree and Xcode project, renamed to the NOX V2 project/scheme.
- Four localization resources: en, vi, es, zh-Hans.
- Original NOX V1 patch resources referenced by the project.
- Existing V1 assets, helper files, views, license flow and patch-related source retained.
- GitHub Actions workflow at `.github/workflows/build-ipa.yml` with preflight checks for project, scheme, localization and patch files.

## Build on GitHub
Upload the **contents** of this ZIP to the repository root (not the ZIP file itself), preserving hidden `.github` directory and all folders. Commit, then open Actions → Build NOX V2 IPA → Run workflow. The workflow produces an **unsigned** IPA artifact. Signing is a separate step required before ordinary device installation.

## Important verification status
The source archive and required resource paths were checked in this environment. This environment does not include macOS/Xcode, so an actual iOS compile, archive, signing operation, or on-device test has not been run here. No one can honestly guarantee “zero errors” before the GitHub macOS build and device tests pass. If a new compiler error appears, use the full Actions log to fix it.

## Backend/security note
The existing V1 license/backend implementation is retained for compatibility. Review the existing MockAPI-backed activation design before production use; it is not a production-grade authorization backend. Existing low-level device modules are carried forward unchanged, not expanded or made to bypass platform security controls.
