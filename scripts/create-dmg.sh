#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output="${1:-$repo_dir/dist/MacZipper.dmg}"

if [[ $# -gt 1 || "$output" != *.dmg ]]; then
    echo "Usage: $0 [output.dmg]" >&2
    exit 2
fi

for tool in xcodegen xcodebuild create-dmg ditto; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Required tool not found: $tool" >&2
        exit 1
    fi
done

mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
if [[ -e "$output" ]]; then
    echo "Output already exists: $output" >&2
    exit 1
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/maczipper-dmg.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT
build_dir="$work_dir/DerivedData"
stage_dir="$work_dir/stage"
mkdir -p "$stage_dir"

xcodegen generate --project "$repo_dir"
xcodebuild build -quiet \
    -project "$repo_dir/MacZipper.xcodeproj" \
    -scheme MacZipper \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$build_dir" \
    "SYMROOT=$build_dir/Build/Products" \
    "OBJROOT=$build_dir/Build/Intermediates.noindex"

app="$build_dir/Build/Products/Release/MacZipper.app"
if [[ ! -d "$app" ]]; then
    echo "Release app not found: $app" >&2
    exit 1
fi
ditto "$app" "$stage_dir/MacZipper.app"

create-dmg \
    --volname "MacZipper" \
    --window-size 600 360 \
    --icon-size 128 \
    --icon "MacZipper.app" 155 175 \
    --app-drop-link 445 175 \
    "$output" "$stage_dir"

echo "Created $output"
