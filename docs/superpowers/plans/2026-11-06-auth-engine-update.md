# Restore Linux authentication engine update

> **For agentic workers:** Use superpowers:executing-plans inline.

**Goal:** Prepare the upstream authentication fixes for the user's Linux Restore installation while preserving the required work VPN.

**Architecture:** Build official ipatool commit d9c0247daea564d3ec7d04a9b015d0a29af66b04 (2.8.0 development) instead of Linux 2.7.0. Pin the source archive checksum and Go toolchain, retain binary integrity verification, adapt cache readiness to the new Apple assets, and redact 2FA codes in diagnostic commands.

**Tech Stack:** Existing Python/Qt/PyInstaller; Go 1.26.5 and a C compiler for upstream ipatool's dependencies.

**Spec:** User reports sign-in failures with HTML/empty HTTP 301/403/404/503 responses. VPN is mandatory and must not be changed. The upstream maintainer recommends main until 2.8.0 is released: https://github.com/majd/ipatool/issues/627.

## Global Constraints

- Continue in the clean feat/linux checkout, without another worktree.
- Preserve the running GUI until a replacement is ready.
- Never request or extract the user's Apple password, token or 2FA code; the user enters them in the application.
- Do not change VPN, routes, DNS or TLS verification.
- Pin official source provenance and validate the resulting binary before packaging.
- Do not claim successful Apple authentication until the user verifies it.

## Review Focus

- Repeated source builds must pass the existing embedded-binary integrity check.
- Source generation for upstream tests must not alter the pinned production build input.
- New runtime asset preparation uses public Apple files and no account credentials.
- GUI tests and build checks must isolate their session files.
- 2FA values must be masked when a diagnostic command is logged.

## Task 1: Update and validate Linux engine

**Files:** build_linux.sh, restore_gui/apple.py, restore_apps.py, tests/test_logic.py, README.md.

- [ ] Build the pinned upstream engine and run its relevant official tests.
- [ ] Observe the real new binary fail the old integrity test; add tests for the new asset cache and 2FA redaction and observe them fail.
- [ ] Implement the minimal Linux source-build recipe, update its expected digest/cache path and secret flag list.
- [ ] Run the full Restore suite, package a replacement, and validate embedded CLI compatibility and frozen UI.
- [ ] Restart the GUI gracefully with the replacement and ask the user to verify one login on the unchanged VPN.
- [ ] Record the actual outcome, review changes, commit and push the completed fix.

## Execution record

The pinned development engine was built and tested. Real login still returned unusable Apple responses with both tested application network paths. A browser SAP proof also failed and was stopped. These failures do not establish an account ban or an invalid password. No usable account session or IPA download was confirmed.

The user clarified that account A reached the 2FA prompt before switching to B and back to A. Follow-up work is tracked in `2026-11-07-auth-session-isolation.md`. Detailed local diagnostics remain in the ignored build directory; infrastructure addresses and local browser storage are not part of the source change.
