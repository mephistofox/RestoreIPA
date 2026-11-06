# Restore Linux build

> **For agentic workers:** Use superpowers:executing-plans to implement this plan inline. Steps use checkbox syntax.

**Goal:** Build and run the existing Restore GUI on this Linux x86_64 machine, with bundled ipatool and the USB installer.

**Architecture:** Keep Qt/QML and pymobiledevice3. Extend the existing PyInstaller specification for Linux and add a Linux build script that uses the existing pinned dependencies and verified upstream ipatool release. Package the resulting directory as a tar.gz archive.

**Tech Stack:** Python 3.12, PySide6, pymobiledevice3, PyInstaller, Bash.

**Spec:** User request: fork RestoreIPA and build it for Linux to install applications on an iPhone 14 Pro.

## Global Constraints

- Preserve the existing interface and Windows/macOS build paths.
- Use the user's existing Git identity, the fork mephistofox/RestoreIPA, and branch feat/linux from upstream 9ad4d12.
- Work directly in this new, clean clone; no additional worktree is needed.
- Do not enter Apple credentials or install anything on the phone during build checks.
- Linux x86_64 is the initial target; do not claim compatibility with older glibc systems or other architectures without verification.

## Review Focus

- Linux must never bundle Windows executables or DLLs.
- Qt dependencies for native Wayland and X11 must survive trimming.
- Embedded ipatool must pass the integrity check after packaging.
- The frozen pymobiledevice3 entry point must start without loading unrelated optional commands.
- UI/build checks must isolate their state from the user's actual app session.

## Task 1: Linux runtime and build

**Files:** modify RestoreAppStore.spec, restore_gui/apple.py, restore_gui/backend.py, tests/test_logic.py, README.md; create build_linux.sh.

- [x] Extend the real bundled-ipatool integrity test to Linux; stage the already verified official binary under build/res and observe the missing Linux hash fail.
- [x] Add the verified Linux x86_64 hash and Linux-specific USB instructions.
- [x] Extend the spec with Unix binaries, Linux Qt dependency retention, and directory packaging without Windows version resources.
- [x] Add build_linux.sh: Python environment, hash-locked dependencies, verified ipatool, full tests, PyInstaller, isolated UI/installer checks, tar.gz and SHA-256 output.
- [x] Document Linux build/run prerequisites and host compatibility limits.
- [x] Run the full test suite, build, and check the frozen UI and pymobiledevice3 version. Expected: zero failures and a working Linux archive.
- [x] Inspect the running native GUI, review the complete diff, commit with the configured identity, and push feat/linux to the requested fork.

## Execution record

- Initial inspection: the runtime already has a Linux data-directory fallback; the build spec treats every non-macOS host as Windows and lacks Linux ipatool integrity hashes.
- Final review found Windows-only wintun DLLs inside collected dependency data. A real artifact assertion failed before filtering; the rebuilt artifact passes the same assertion and all 72 tests (6 platform-specific skips).
- Final Linux bundle: `dist/linux/RestoreAppStore`. Native Wayland startup, frozen UI, embedded ipatool integrity, pymobiledevice3 version, and targeted USB installer command loading verified. Real Apple login, iPhone installation, Windows/macOS execution and older Linux systems are not verified.
