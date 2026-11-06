#!/usr/bin/env bash
# Linux x86_64: directory bundle plus tar.gz; Python 3.12 or an existing build/linux-venv.
set -euo pipefail
cd "$(dirname "$0")"

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "Эта сборка предназначена для Linux x86_64." >&2
    exit 1
fi

if [[ ! -x build/linux-venv/bin/python ]]; then
    "${PYTHON:-python3.12}" -m venv build/linux-venv
fi
RESTORE_PYTHON=build/linux-venv/bin/python
"$RESTORE_PYTHON" -c 'import sys; assert sys.version_info[:2] == (3, 12), "Нужен Python 3.12"'
"$RESTORE_PYTHON" -m pip install --disable-pip-version-check -q --require-hashes -r requirements-lock.txt

RESTORE_IPATOOL_VERSION=2.7.0
RESTORE_IPATOOL_SHA=68372de9743d468296f2dba5b413a3e7df56ad0c85b8d0f4f0f6c9b8b53a54e8
RESTORE_TAR="build/dl/ipatool-$RESTORE_IPATOOL_VERSION-linux-amd64.tar.gz"
mkdir -p build/dl build/res
if [[ ! -f "$RESTORE_TAR" ]] || ! printf '%s  %s\n' "$RESTORE_IPATOOL_SHA" "$RESTORE_TAR" | sha256sum -c --status; then
    curl -fL --connect-timeout 15 --max-time 180 -o "$RESTORE_TAR" \
        "https://github.com/majd/ipatool/releases/download/v$RESTORE_IPATOOL_VERSION/ipatool-$RESTORE_IPATOOL_VERSION-linux-amd64.tar.gz"
fi
printf '%s  %s\n' "$RESTORE_IPATOOL_SHA" "$RESTORE_TAR" | sha256sum -c -
tar -xOf "$RESTORE_TAR" "bin/ipatool-$RESTORE_IPATOOL_VERSION-linux-amd64" > build/res/ipatool
chmod +x build/res/ipatool
build/res/ipatool --version

QT_QPA_PLATFORM=offscreen "$RESTORE_PYTHON" -m unittest discover -s tests -q
if ! "$RESTORE_PYTHON" -m PyInstaller --noconfirm --clean --distpath dist/linux RestoreAppStore.spec > build/linux-build.log 2>&1; then
    tail -n 80 build/linux-build.log >&2
    exit 1
fi

# Checks run with a private child-process home, never against an existing Restore session.
"$RESTORE_PYTHON" - <<'PY'
import os
import subprocess
import tempfile
from pathlib import Path

bundle = Path("dist/linux/RestoreAppStore")
foreign = [str(p) for p in bundle.rglob("*") if p.suffix.lower() in (".dll", ".exe")]
if foreign:
    raise SystemExit(f"В Linux-сборку попали файлы Windows: {foreign}")
exe = str((bundle / "RestoreAppStore").resolve())
with tempfile.TemporaryDirectory(prefix="restore-build-check-") as check_dir:
    env = dict(os.environ, HOME=check_dir, QT_QPA_PLATFORM="offscreen")
    for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        env[key] = str(Path(check_dir) / key.lower())
    report = Path(check_dir) / "ui-report.txt"
    result = subprocess.run([exe, "--check-ui", str(report)], env=env)
    if report.exists():
        print(report.read_text(), flush=True)
    result.check_returncode()
    subprocess.run([exe, "--pmd", "version"], env=env, check=True)
    for command in (("apps", "install"), ("lockdown", "info")):
        subprocess.run([exe, "--pmd", *command, "--help"], env=env, check=True,
                       stdout=subprocess.DEVNULL)
PY

RESTORE_VERSION=$("$RESTORE_PYTHON" -c 'import restore_apps; print(restore_apps.__version__)')
RESTORE_ARCHIVE="Restore-$RESTORE_VERSION-linux-x86_64.tar.gz"
tar -czf "dist/$RESTORE_ARCHIVE" -C dist/linux RestoreAppStore
(cd dist && sha256sum "$RESTORE_ARCHIVE" > "$RESTORE_ARCHIVE.sha256")
cat "dist/$RESTORE_ARCHIVE.sha256"
echo "Готово: dist/$RESTORE_ARCHIVE"
