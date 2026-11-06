# Authentication session isolation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A new login must not reuse an abandoned account's cookies; Restore must not silently repeat failed password submissions.

**Architecture:** Keep the existing password then explicit 2FA flow. Isolate the Linux child home and file keyring, clear abandoned state once per new login, and apply a small reproducible patch to the pinned ipatool engine that opts out of authentication retries.

**Tech Stack:** Python 3.12, PySide6, pinned ipatool d9c0247, Go 1.26.5.

**Spec:** User's diagnostic report: account A reached 2FA, account B failed, returning to A failed. This plan addresses that failure path; persistent multiple accounts and a combined library remain separate work.

## Global Constraints

- No live Apple authentication or access to users' passwords, tokens or keyring items during verification.
- Preserve the required work VPN and all system network settings.
- Continue in the existing feat/linux checkout; preserve the earlier engine update and redaction work.
- Keep cookies through the explicit second-factor continuation; discard them only at a fresh login.
- Keep macOS and Windows behavior unchanged and verify the bundled engine by SHA256.

## Review Focus

- Inherited XDG variables must not redirect session writes out of the private home.
- A desktop Secret Service must not make different private homes share one account.
- Cancelling 2FA and trying B then A must not transfer cookies across attempts.
- Providing 2FA during the same login must preserve that attempt's cookies.
- HTTP/transport failures and decoded credential errors must not trigger hidden retries; legitimate Store redirects remain supported.

### Task 1: Isolate and bound native authentication

**Files:** Modify restore_apps.py, restore_gui/tasks.py, restore_gui/apple.py, build_linux.sh, tests/test_logic.py, tests/test_ui.py, README.md and THIRD_PARTY_NOTICES.md. Create patches/ipatool-restore-auth.patch with upstream tests and production changes.

**Interfaces:** Consumes core.ipatool_env(home=None), TasksMixin.task_login(ipatool, email, password), wipe_session(revoke=True), appstore.Args. Produces the same Python interfaces and an optional DisableAuthenticationRetries boolean used only by Restore's Linux child.

- [x] Write regression tests asserting no prior cookie on each fresh A/B/A attempt, retention of the challenge cookie when adding --auth-code, and no writes to inherited XDG state directories using the real embedded CLI with an empty test home. Verify they fail for stale cookies and escaped state.
- [x] Isolate the Linux child's state environment, suppress its desktop Secret Service connection so the existing encrypted file fallback is used, and wipe abandoned state once before the login loop. Run `QT_QPA_PLATFORM=offscreen build/linux-venv/bin/python -m unittest discover -s tests -q`; expected: all tests pass, platform skips allowed.
- [x] Add upstream regression tests for one request on 204/503/transport errors and no retry on a decoded credential rejection when opted out; default retry and redirect tests remain passing. Observe RED then add the boolean to Args and wire it from IPATOOL_DISABLE_AUTH_RETRIES=1 in cmd/common.go.
- [x] Generate a minimal patch from verified pristine source, apply it during build, rebuild with Go 1.26.5, update the expected engine digest and document the patched provenance. Run Go tests for cmd, pkg/... and internal/store/...; expected: pass without Apple requests.
- [x] Run `RESTORE_DIST_ROOT=dist/linux-auth-isolated bash build_linux.sh`; expected: Python suite, embedded integrity check, frozen UI/helper checks and archive creation pass. Point the local restore launcher at the verified bundle without submitting a login.
- [ ] Review and commit the bounded fix with existing user identity. Do not merge. Final report must distinguish tested local fixes from unverified Apple authentication.

## Verification record

2026-11-07: Python suite 78 tests, OK (6 platform skips). Go cmd, pkg/... and internal/store/... passed, including opt-out tests for HTTP failures, transport failures, credential rejection, redirects and 2FA. A fresh verified upstream archive with the committed patch produced engine SHA256 `d0821d31cdd27acc3e7a33a1e5310a44d22ce22008e1cfa0688a9ce13dadaa09`. The isolated frozen bundle passed GUI and USB-helper checks. Archive SHA256: `6b895f677ddd129c67845f9a3a3cc27b422209b5ebc49500c755c4ca712672f7`. No live account login was attempted.
