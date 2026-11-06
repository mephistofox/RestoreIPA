#!/usr/bin/env bash
# Linux x86_64: directory bundle plus tar.gz; Python 3.12 or an existing build/linux-venv.
set -euo pipefail
cd "$(dirname "$0")"
RESTORE_DIST_ROOT="${RESTORE_DIST_ROOT:-dist/linux}"

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

RESTORE_IPATOOL_REV=d9c0247daea564d3ec7d04a9b015d0a29af66b04
RESTORE_IPATOOL_VERSION=2.8.0-dev.d9c0247.restore1
RESTORE_SOURCE_SHA=13c10c4021fefc9614af97c67bf43cd7cf79b255079f6697fe35d252d24c4f9f
RESTORE_TAR="build/dl/ipatool-d9c0247-source.tar.gz"
mkdir -p build/dl build/res
if [[ ! -f "$RESTORE_TAR" ]] || ! printf '%s  %s\n' "$RESTORE_SOURCE_SHA" "$RESTORE_TAR" | sha256sum -c --status; then
    curl -fL --connect-timeout 15 --max-time 180 -o "$RESTORE_TAR" \
        "https://codeload.github.com/majd/ipatool/tar.gz/$RESTORE_IPATOOL_REV"
fi
printf '%s  %s\n' "$RESTORE_SOURCE_SHA" "$RESTORE_TAR" | sha256sum -c -
# A fresh source tree keeps generated test mocks out of the production binary.
RESTORE_SOURCE_DIR=$(mktemp -d build/ipatool-src.XXXXXX)
trap 'rm -rf "$RESTORE_SOURCE_DIR"' EXIT
tar -xzf "$RESTORE_TAR" -C "$RESTORE_SOURCE_DIR" --strip-components=1
patch --batch --forward -p1 -d "$RESTORE_SOURCE_DIR" < patches/ipatool-restore-auth.patch
RESTORE_BINARY_OUT="$(pwd)/build/res/ipatool"
(cd "$RESTORE_SOURCE_DIR" && GOTOOLCHAIN=go1.26.5 CGO_ENABLED=1 GOOS=linux GOARCH=amd64 GOAMD64=v1 \
    GOEXPERIMENT= GOFLAGS= go build -trimpath -buildvcs=false \
    -ldflags="-s -w -X github.com/majd/ipatool/v2/cmd.version=$RESTORE_IPATOOL_VERSION" \
    -o "$RESTORE_BINARY_OUT" .)
RESTORE_BINARY_SHA=$(sha256sum build/res/ipatool)
RESTORE_BINARY_SHA=${RESTORE_BINARY_SHA%% *}
printf 'IPATOOL_SHA256 = "%s"\n' "$RESTORE_BINARY_SHA" > build/res/restore_linux_engine.py
build/res/ipatool --version

QT_QPA_PLATFORM=offscreen "$RESTORE_PYTHON" -m unittest discover -s tests -q
if ! "$RESTORE_PYTHON" -m PyInstaller --noconfirm --clean --distpath "$RESTORE_DIST_ROOT" RestoreAppStore.spec > build/linux-build.log 2>&1; then
    tail -n 80 build/linux-build.log >&2
    exit 1
fi

# Checks run with a private child-process home, never against an existing Restore session.
"$RESTORE_PYTHON" - "$RESTORE_DIST_ROOT" <<'PY'
import os
import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path
from PyInstaller.archive.readers import CArchiveReader

bundle = Path(sys.argv[1]) / "RestoreAppStore"
foreign = [str(p) for p in bundle.rglob("*") if p.suffix.lower() in (".dll", ".exe")]
if foreign:
    raise SystemExit(f"В Linux-сборку попали файлы Windows: {foreign}")
exe = str((bundle / "RestoreAppStore").resolve())
compiled_digest = CArchiveReader(exe).open_embedded_archive("PYZ.pyz").extract("restore_linux_engine")
engine_digest = hashlib.sha256((bundle / "_internal" / "ipatool").read_bytes()).hexdigest()
assert engine_digest in compiled_digest.co_consts, "Packaged engine does not match its compiled digest"
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
tar -czf "dist/$RESTORE_ARCHIVE" -C "$RESTORE_DIST_ROOT" RestoreAppStore
(cd dist && sha256sum "$RESTORE_ARCHIVE" > "$RESTORE_ARCHIVE.sha256")
cat "dist/$RESTORE_ARCHIVE.sha256"
echo "Готово: dist/$RESTORE_ARCHIVE"
