#!/usr/bin/env bash
# Extract user-owned GTA:LCS Android files into a private runtime directory.
# Source archives are never modified or deleted.

set -euo pipefail

EXPECTED_GAME_SHA256=d581f68eaa8c6831c3796e241e11deea2be32f442b4e587f85dc34bd2cd856ab
EXPECTED_OPENAL_SHA256=2cb52c89b85e8ba1e397068e43fdc80ec5694e06600522c74e9fb51aaf598583
EXPECTED_MPG123_SHA256=92d407574a05e30c34644c6fe649b20345f1e6833608733e699f79d5865ad80a
EXPECTED_MAIN_SHA256=e9a61648b6f28427a95f3b3038051c01469c8bcf4cecfcd91321e74ca1d81220
READY_MARKER=.lcs-2.4.379-ready

usage() {
    cat >&2 <<EOF
Usage: $0 <APK-or-directory> [more APKs/directories ...] <output-directory>
       $0 --verify <output-directory>

Example: $0 source-apks gamefiles

The tested GTA:LCS 2.4.379 ARM64 hashes are required. Set
LCS_ALLOW_UNTESTED=1 only when intentionally investigating another build.
A legally recovered data_music.wad may be supplied directly or inside an input
directory; it is copied but cannot be version-pinned because no reference copy
is distributed with this project.
EOF
}

verify_only=0
if [[ ${1:-} == --verify ]]; then
    verify_only=1
    shift
    if (( $# != 1 )); then
        usage
        exit 2
    fi
elif (( $# < 2 )); then
    usage
    exit 2
fi

for tool in awk cp find mkdir mktemp mv rm tr unzip; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Missing required tool: $tool" >&2
        exit 1
    }
done

if command -v sha256sum >/dev/null 2>&1; then
    hash_file() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
    hash_file() { shasum -a 256 "$1" | awk '{print $1}'; }
else
    echo "Missing required SHA-256 tool (sha256sum or shasum)." >&2
    exit 1
fi

validate_build() {
    local root=$1
    local library="$root/android-libs/libGame.so"
    local openal="$root/android-libs/libopenal.so"
    local mpg123="$root/android-libs/libVendor_mpg123.so"
    local data_main="$root/assets/data_main.wad"
    local mismatch=0

    for required in "$library" "$openal" "$mpg123" "$data_main"; do
        if [[ ! -s "$required" ]]; then
            echo "Missing required private file: $required" >&2
            return 1
        fi
    done

    echo "Verifying libGame.so"
    VALID_GAME_HASH=$(hash_file "$library")
    echo "Verifying libopenal.so"
    VALID_OPENAL_HASH=$(hash_file "$openal")
    echo "Verifying libVendor_mpg123.so"
    VALID_MPG123_HASH=$(hash_file "$mpg123")
    echo "Verifying data_main.wad (this can take a minute)"
    VALID_MAIN_HASH=$(hash_file "$data_main")

    [[ $VALID_GAME_HASH == "$EXPECTED_GAME_SHA256" ]] || mismatch=1
    [[ $VALID_OPENAL_HASH == "$EXPECTED_OPENAL_SHA256" ]] || mismatch=1
    [[ $VALID_MPG123_HASH == "$EXPECTED_MPG123_SHA256" ]] || mismatch=1
    [[ $VALID_MAIN_HASH == "$EXPECTED_MAIN_SHA256" ]] || mismatch=1

    if (( mismatch != 0 )); then
        echo "Unsupported or mismatched Android files:" >&2
        echo "  libGame.so:          $VALID_GAME_HASH" >&2
        echo "  libopenal.so:        $VALID_OPENAL_HASH" >&2
        echo "  libVendor_mpg123.so: $VALID_MPG123_HASH" >&2
        echo "  data_main.wad:       $VALID_MAIN_HASH" >&2
        echo "Expected the matching GTA:LCS 2.4.379 ARM64 files." >&2
        if [[ ${LCS_ALLOW_UNTESTED:-0} != 1 ]]; then
            echo "Refusing installation; set LCS_ALLOW_UNTESTED=1 to override." >&2
            return 1
        fi
        echo "Continuing because LCS_ALLOW_UNTESTED=1." >&2
    fi
}

marker_has_line() {
    local marker=$1 expected=$2 line
    [[ -f $marker ]] || return 1
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line == "$expected" ]] && return 0
    done <"$marker"
    return 1
}

marker_has_prefix() {
    local marker=$1 expected=$2 line
    [[ -f $marker ]] || return 1
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line == "$expected"* ]] && return 0
    done <"$marker"
    return 1
}

verify_marker() {
    local root=$1 marker="$1/$READY_MARKER"
    marker_has_line "$marker" 'package=com.rockstargames.gtalcs' &&
        marker_has_line "$marker" 'version=2.4.379' &&
        marker_has_line "$marker" "libGame.sha256=$VALID_GAME_HASH" &&
        marker_has_line "$marker" "libopenal.sha256=$VALID_OPENAL_HASH" &&
        marker_has_line "$marker" "libVendor_mpg123.sha256=$VALID_MPG123_HASH" &&
        marker_has_line "$marker" "data_main.sha256=$VALID_MAIN_HASH" || {
        echo "Missing or stale ready marker: $marker" >&2
        return 1
    }

    if [[ -s "$root/assets/data_music.wad" ]]; then
        local music_hash
        music_hash=$(hash_file "$root/assets/data_music.wad")
        marker_has_line "$marker" "data_music.sha256=$music_hash" || {
            echo "Ready marker does not describe the installed data_music.wad." >&2
            return 1
        }
    elif marker_has_prefix "$marker" 'data_music.sha256='; then
        echo "Ready marker describes a data_music.wad that is not installed." >&2
        return 1
    fi
}

if (( verify_only != 0 )); then
    output=$1
    if [[ -z $output || $output == / || ! -d $output ]]; then
        echo "Unsafe or missing output directory: '$output'" >&2
        exit 2
    fi
    output=$(cd "$output" && pwd -P)
    validate_build "$output"
    verify_marker "$output"
    echo "PASS: verified private GTA:LCS files and ready marker in $output"
    exit 0
fi

args=("$@")
last_index=$((${#args[@]} - 1))
output=${args[$last_index]}
unset "args[$last_index]"

if [[ -z $output || $output == / ]]; then
    echo "Refusing unsafe output directory: '$output'" >&2
    exit 2
fi

mkdir -p "$output"
output=$(cd "$output" && pwd -P)
stage=$(mktemp -d "$output/.lcs-setup.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'exit 130' INT TERM HUP
mkdir -p "$stage/splits" "$stage/android-libs" "$stage/assets"

sources=()
direct_music_sources=()

add_source() {
    local candidate=$1 lower
    [[ -f $candidate ]] || return 0
    lower=$(printf '%s' "$candidate" | tr '[:upper:]' '[:lower:]')
    case "$lower" in
        *.apk|*.apks|*.apkm|*.xapk|*.zip) sources+=("$candidate") ;;
    esac
}

add_music_source() {
    local candidate=$1 basename_lower
    [[ -s $candidate ]] || return 0
    basename_lower=$(printf '%s' "${candidate##*/}" | tr '[:upper:]' '[:lower:]')
    [[ $basename_lower == data_music.wad ]] && direct_music_sources+=("$candidate")
}

for input in "${args[@]}"; do
    if [[ -d $input ]]; then
        while IFS= read -r -d '' file; do
            add_source "$file"
        done < <(find "$input" -maxdepth 1 -type f \( \
            -iname '*.apk' -o -iname '*.apks' -o -iname '*.apkm' -o \
            -iname '*.xapk' -o -iname '*.zip' \) -print0)
        while IFS= read -r -d '' file; do
            add_music_source "$file"
        done < <(find "$input" -maxdepth 3 -type f -iname 'data_music.wad' -print0)
    else
        add_source "$input"
        add_music_source "$input"
    fi
done

if (( ${#sources[@]} == 0 && ${#direct_music_sources[@]} == 0 )); then
    echo "No APK, split bundle, or data_music.wad was found in the supplied inputs." >&2
    exit 1
fi

if (( ${#direct_music_sources[@]} > 0 )); then
    music_source=${direct_music_sources[0]}
    music_source_hash=$(hash_file "$music_source")
    for candidate in "${direct_music_sources[@]}"; do
        candidate_hash=$(hash_file "$candidate")
        if [[ $candidate_hash != "$music_source_hash" ]]; then
            echo "Multiple different data_music.wad files were supplied; choose one explicitly." >&2
            exit 1
        fi
    done
    echo "Staging user-supplied data_music.wad"
    cp -p -- "$music_source" "$stage/assets/data_music.wad"
fi

# Expose APKs nested one level inside APKS/APKM/XAPK/ZIP bundles. Bash 3.2
# treats an empty-array expansion as unbound under `set -u`, so do not expand
# the array at all in music-only mode.
if (( ${#sources[@]} > 0 )); then
    original_sources=("${sources[@]}")
    split_number=0
    for bundle in "${original_sources[@]}"; do
        while IFS= read -r entry; do
            [[ -n $entry ]] || continue
            split_number=$((split_number + 1))
            split="$stage/splits/${split_number}-${entry##*/}"
            if unzip -p "$bundle" "$entry" >"$split" 2>/dev/null && [[ -s $split ]]; then
                sources+=("$split")
            else
                rm -f -- "$split"
            fi
        done < <(unzip -Z1 "$bundle" 2>/dev/null | awk 'tolower($0) ~ /[.]apk$/')
    done
fi

extract_first() {
    local destination=$1
    shift
    local source entry
    [[ ! -s $destination ]] || return 0
    for source in "${sources[@]}"; do
        for entry in "$@"; do
            if unzip -p "$source" "$entry" >"$destination" 2>/dev/null && [[ -s $destination ]]; then
                echo "Extracted ${destination#"$stage/"}"
                return 0
            fi
            rm -f -- "$destination"
        done
    done
    return 1
}

if (( ${#sources[@]} > 0 )); then
    extract_first "$stage/android-libs/libGame.so" \
        'lib/arm64-v8a/libGame.so' || {
        echo "ARM64 libGame.so was not found. This port requires an arm64-v8a split." >&2
        exit 1
    }

    extract_first "$stage/android-libs/libopenal.so" \
        'lib/arm64-v8a/libopenal.so' || {
        echo "ARM64 libopenal.so was not found in the supplied split set." >&2
        exit 1
    }
    extract_first "$stage/android-libs/libVendor_mpg123.so" \
        'lib/arm64-v8a/libVendor_mpg123.so' || {
        echo "ARM64 libVendor_mpg123.so was not found in the supplied split set." >&2
        exit 1
    }
    extract_first "$stage/android-libs/libz.so" 'lib/arm64-v8a/libz.so' || true

    extract_first "$stage/assets/data_main.wad" \
        'assets/data_main.wad' 'data_main.wad' || {
        echo "data_main.wad was not found. Supply the data_main asset-pack split." >&2
        exit 1
    }
    extract_first "$stage/assets/data_music.wad" \
        'assets/data_music.wad' 'data_music.wad' || true

    validate_build "$stage"
else
    # This mode lets a later legally recovered music pack be added without
    # requiring the user to copy their APK splits back to the computer.
    validate_build "$output"
fi

# Each replacement is a same-filesystem rename. The marker is removed first
# and written last, so an interrupted install cannot masquerade as complete.
rm -f -- "$output/$READY_MARKER"
mkdir -p "$output/android-libs" "$output/assets"
for file in "$stage/android-libs"/*; do
    [[ -f $file ]] && mv -f -- "$file" "$output/android-libs/"
done
if [[ -s "$stage/assets/data_main.wad" ]]; then
    mv -f -- "$stage/assets/data_main.wad" "$output/assets/data_main.wad"
fi
if [[ -s "$stage/assets/data_music.wad" ]]; then
    mv -f -- "$stage/assets/data_music.wad" "$output/assets/data_music.wad"
fi

# Hash the installed paths again before publishing the ready marker.
validate_build "$output"
{
    echo 'package=com.rockstargames.gtalcs'
    echo 'version=2.4.379'
    echo "libGame.sha256=$VALID_GAME_HASH"
    echo "libopenal.sha256=$VALID_OPENAL_HASH"
    echo "libVendor_mpg123.sha256=$VALID_MPG123_HASH"
    echo "data_main.sha256=$VALID_MAIN_HASH"
    if [[ -s "$output/assets/data_music.wad" ]]; then
        echo "data_music.sha256=$(hash_file "$output/assets/data_music.wad")"
    fi
} >"$stage/ready-marker"
mv -f -- "$stage/ready-marker" "$output/$READY_MARKER"

verify_marker "$output"
echo
echo "LCS private game files are ready in: $output"
if [[ -s "$output/assets/data_music.wad" ]]; then
    echo "Optional data_music.wad is installed and recorded in the ready marker."
else
    echo "data_music is absent; it may be installed later with this same tool."
fi
