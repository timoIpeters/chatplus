#!/usr/bin/env bash
# Builds a release: runs the tests, compiles the mod, writes configFormats.json and packs it with README.md and LICENSE into
# build/release/chat-plus-<version>.zip with hlx/mods/chat-plus/ inside (for Vortex or extracting
# into the Farever folder). The version comes from src/chatplus/Version.hx.
#
# Release steps:
#   1. Set VERSION in src/chatplus/Version.hx (x.y.Z fix, x.Y.0 feature, X.0.0 big change).
#   2. ./release.sh
#   3. Install the zip on the gaming PC (extract into the Farever folder or add it in Vortex), start the game, run /chatplus.
#   4. git commit, git tag v<version>
#   5. Nexus Mods: upload the zip with the same version number, add a changelog line.
set -euo pipefail
cd "$(dirname "$0")"

version="$(sed -n 's/.*VERSION = "\(.*\)".*/\1/p' src/chatplus/Version.hx)"
[ -n "$version" ] || { echo "No VERSION in src/chatplus/Version.hx"; exit 1; }
[ -d vendor/hlx-core ] || { echo "vendor/hlx-core missing: git clone --depth 1 https://github.com/hlx-framework/hlx-core.git vendor/hlx-core"; exit 1; }

haxe test.hxml
haxe compile.hxml 2>&1 | grep -v "initialization macros" || true
[ -f build/chat-plus/chat-plus.hl ] || { echo "Build failed: build/chat-plus/chat-plus.hl missing"; exit 1; }

stage="build/release/stage/hlx/mods/chat-plus"
rm -rf build/release/stage
mkdir -p "$stage"
cp build/chat-plus/chat-plus.hl "$stage/"
haxe formats.hxml "$stage/configFormats.json" > /dev/null
cp README.md LICENSE "$stage/"

zip="build/release/chat-plus-$version.zip"
rm -f "$zip"
python3 - "$zip" build/release/stage <<'PY'
import os, sys, zipfile
out, root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for folder, _, files in os.walk(root):
        for name in sorted(files):
            path = os.path.join(folder, name)
            z.write(path, os.path.relpath(path, root).replace(os.sep, "/"))
PY
rm -rf build/release/stage
echo "release: $zip"
python3 -c "import zipfile,sys; [print('  ' + n) for n in zipfile.ZipFile(sys.argv[1]).namelist()]" "$zip"
