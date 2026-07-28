#!/usr/bin/env bash

set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
ARCHIVE="$ROOT/gtalcs.zip"

for tool in awk bash cmp grep mktemp rm sed unzip; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Missing required verification tool: $tool" >&2
        exit 1
    }
done

bash -n "$ROOT/extract_lcs.sh" \
    "$ROOT/extract_music_from_rooted_android.sh"
(
    cd "$ROOT"
    expected=$(awk '$2 == "gtalcs.zip" { print $1 }' SHA256SUMS)
    if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum gtalcs.zip | awk '{ print $1 }')
    elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 gtalcs.zip | awk '{ print $1 }')
    else
        echo "Missing required SHA-256 tool." >&2
        exit 1
    fi
    [ -n "$expected" ] && [ "$actual" = "$expected" ] || {
        echo "gtalcs.zip SHA-256 mismatch." >&2
        exit 1
    }
)
unzip -tq "$ARCHIVE" >/dev/null

if unzip -Z1 "$ARCHIVE" | grep -Eiq \
    '(^|/)(gamefiles|userdata|logs)/|[.](apk|apks|apkm|xapk|wad|obb|ab)$|[.]so([.][0-9]+)*$'; then
    echo "Release archive contains private or copyrighted game data." >&2
    exit 1
fi

stage=$(
    unzip -p "$ARCHIVE" gtalcs/lcs.conf.default |
        sed -n 's/^stage=//p'
)
[ "$stage" = game ] || {
    echo "Public package does not default to the game stage." >&2
    exit 1
}
unzip -p "$ARCHIVE" "Grand Theft Auto Liberty City Stories.sh" |
    grep -q '^CONFIG_STAGE=game$'
unzip -p "$ARCHIVE" gtalcs/port.json |
    grep -q '"exp": false'

temporary=$(mktemp -d "${TMPDIR:-/tmp}/gtalcs-release.XXXXXX")
trap 'rm -rf -- "$temporary"' EXIT
unzip -q "$ARCHIVE" -d "$temporary"
bash -n "$temporary/Grand Theft Auto Liberty City Stories.sh" \
    "$temporary/gtalcs/setup.sh" "$temporary/gtalcs/audio.sh"
cmp -s "$ROOT/LICENSE" "$temporary/gtalcs/licenses/MIT.txt" || {
    echo "Packaged MIT licence does not match repository LICENSE." >&2
    exit 1
}
cmp -s "$ROOT/VERSION" "$temporary/gtalcs/VERSION" || {
    echo "Packaged version does not match repository VERSION." >&2
    exit 1
}
[ -s "$temporary/gtalcs/licenses/game-data-notice.txt" ] || {
    echo "Packaged third-party game-data notice is missing." >&2
    exit 1
}

echo "GTA:LCS public release verification: PASS"
