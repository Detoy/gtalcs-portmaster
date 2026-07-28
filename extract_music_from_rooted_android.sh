#!/usr/bin/env bash
# Extract data_music.wad from the owner's rooted Android device for local use.
# The extracted copyrighted asset must never be placed in a distributable ZIP.

set -euo pipefail

PACKAGE=com.rockstargames.gtalcs
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
OUTPUT_DIR=${1:-$SCRIPT_DIR/private-music-extraction}
REMOTE_OVERRIDE=${2:-}
ADB=${ADB:-adb}

if [ "${LCS_CONFIRM_OWNERSHIP:-}" != yes ]; then
    echo "This tool is only for files from your own legitimate GTA:LCS install." >&2
    echo "Re-run with LCS_CONFIRM_OWNERSHIP=yes after confirming ownership." >&2
    exit 2
fi
command -v "$ADB" >/dev/null 2>&1 || {
    echo "adb was not found." >&2
    exit 1
}
"$ADB" get-state >/dev/null 2>&1 || {
    echo "No authorized Android device is available through adb." >&2
    exit 1
}
PACKAGE_PATHS=$("$ADB" shell pm path "$PACKAGE" 2>/dev/null || true)
case "$PACKAGE_PATHS" in
    *package:*) ;;
    *)
        echo "GTA:LCS package $PACKAGE is not installed on the connected device." >&2
        exit 1
        ;;
esac
ROOT_UID=$("$ADB" shell su -c 'id -u' 2>/dev/null | tr -d '\r' | tail -1)
if [ "$ROOT_UID" != 0 ]; then
    echo "Root access through 'su -c' was not granted." >&2
    exit 1
fi

case "$OUTPUT_DIR" in
    ''|/) echo "Refusing unsafe output directory." >&2; exit 2 ;;
esac
mkdir -p "$OUTPUT_DIR"

remote_paths=()
if [ -n "$REMOTE_OVERRIDE" ]; then
    remote_paths+=("$REMOTE_OVERRIDE")
else
    for root in \
        "/data/user/0/$PACKAGE" \
        "/data/data/$PACKAGE" \
        "/data/user_de/0/$PACKAGE" \
        "/data/misc/assetpacks/$PACKAGE" \
        "/data/misc_ce/0/assetpacks/$PACKAGE"; do
        while IFS= read -r candidate; do
            candidate=${candidate%$'\r'}
            [ -n "$candidate" ] || continue
            duplicate=0
            for existing in "${remote_paths[@]}"; do
                [ "$existing" != "$candidate" ] || duplicate=1
            done
            [ "$duplicate" -ne 0 ] || remote_paths+=("$candidate")
        done < <(
            "$ADB" shell su -c \
                "find '$root' -type f -name data_music.wad -print 2>/dev/null" \
                2>/dev/null || true
        )
    done
fi

if [ "${#remote_paths[@]}" -eq 0 ]; then
    echo "data_music.wad was not found in the known private asset locations." >&2
    echo "Open the game once while online and allow all asset downloads to finish." >&2
    exit 1
fi
if [ "${#remote_paths[@]}" -gt 1 ]; then
    echo "Multiple candidates were found:" >&2
    for candidate in "${remote_paths[@]}"; do
        echo "  $candidate" >&2
    done
    echo "Re-run with the selected remote path as the second argument." >&2
    exit 2
fi

REMOTE_PATH=${remote_paths[0]}
case "$REMOTE_PATH" in
    /data/*/data_music.wad) ;;
    *) echo "Refusing unexpected remote path: $REMOTE_PATH" >&2; exit 2 ;;
esac
case "$REMOTE_PATH" in
    *"'"*) echo "Refusing remote path containing a quote." >&2; exit 2 ;;
esac

TEMP="$OUTPUT_DIR/.data_music.wad.$$"
DESTINATION="$OUTPUT_DIR/data_music.wad"
trap 'rm -f -- "$TEMP"' EXIT
"$ADB" exec-out su -c "cat '$REMOTE_PATH'" >"$TEMP"
[ -s "$TEMP" ] || {
    echo "The extracted candidate is empty." >&2
    exit 1
}
chmod 600 "$TEMP"
mv -f -- "$TEMP" "$DESTINATION"
trap - EXIT

if command -v sha256sum >/dev/null 2>&1; then
    MUSIC_SHA256=$(sha256sum "$DESTINATION" | awk '{print $1}')
else
    MUSIC_SHA256=$(shasum -a 256 "$DESTINATION" | awk '{print $1}')
fi
MUSIC_BYTES=$(wc -c <"$DESTINATION")
DEVICE_MODEL=$("$ADB" shell getprop ro.product.model 2>/dev/null | tr -d '\r')
PACKAGE_INFO=$(
    "$ADB" shell dumpsys package "$PACKAGE" 2>/dev/null |
        tr -d '\r' |
        awk '/versionName=|versionCode=/{print; if (++count == 2) exit}'
)

{
    echo "package=$PACKAGE"
    echo "device_model=$DEVICE_MODEL"
    printf '%s\n' "$PACKAGE_INFO"
    echo "remote_path=$REMOTE_PATH"
    echo "data_music.bytes=$MUSIC_BYTES"
    echo "data_music.sha256=$MUSIC_SHA256"
    echo "extracted=$(date -Iseconds 2>/dev/null || date)"
    echo "distribution=PROHIBITED; local validation only"
} >"$OUTPUT_DIR/PROVENANCE.txt"
chmod 600 "$OUTPUT_DIR/PROVENANCE.txt"

echo "Local music asset extracted to:"
echo "$DESTINATION"
echo "bytes=$MUSIC_BYTES"
echo "sha256=$MUSIC_SHA256"
echo
echo "Do not upload or redistribute this file."
echo "Copy it to roms/ports/gtalcs/gamedata/ and launch the port."
