#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")" || exit

# Check that Hyperfine is installed.
if ! command -v hyperfine > /dev/null 2>&1; then
	echo "'hyperfine' does not seem to be installed."
	echo "You can get it here: https://github.com/sharkdp/hyperfine"
	exit 1
fi

# Check that jq is installed.
if ! command -v jq > /dev/null 2>&1; then
	echo "'jq' does not seem to be installed."
	echo "You can get it here: https://stedolan.github.io/jq"
	exit 1
fi

get_cargo_target_dir() {
	cargo metadata --no-deps --format-version 1 | jq -r .target_directory
}

heading() {
    bold=$(tput bold)$(tput setaf 220)
    normal=$(tput sgr0)
    echo
    printf "\n%s%s%s\n\n" "$bold" "$1" "$normal"

    echo -e "\n### $1\n" >> "$REPORT"
}

RESULT_DIR="benchmark-results"
REPORT="$RESULT_DIR/report.md"

TARGET_DIR="$(get_cargo_target_dir)"
TARGET_RELEASE="${TARGET_DIR}/release/bat"

WARMUP_COUNT=3

# Determine which target to benchmark.
BAT=''
for arg in "$@"; do
	case "$arg" in
		--system)  BAT="bat" ;;
		--release) BAT="$TARGET_RELEASE" ;;
		--bat=*)   BAT="${arg:6}" ;;
	esac
done

if [[ -z "$BAT" ]]; then
	echo "A build of 'bat' must be specified for benchmarking."
	echo "You can use '--system', '--release' or '--bat=path/to/bat'."
	exit 1
fi

if ! command -v "$BAT" &>/dev/null; then
	echo "Could not find the build of bat to benchmark ($BAT)."
	case "$BAT" in
		"bat")             echo "Make you sure to symlink 'batcat' as 'bat'." ;;
		"$TARGET_RELEASE") echo "Make you sure to 'cargo build --release' first." ;;
	esac
	exit 1
fi

# Run the benchmarks
mkdir -p "$RESULT_DIR"
rm -f "$RESULT_DIR"/*.md

echo "## \`bat\` benchmark results" >> "$REPORT"

heading "Startup time"
hyperfine \
	"$BAT" \
	--warmup "$WARMUP_COUNT" \
    --export-markdown "$RESULT_DIR/startup-time.md" \
    --export-json "$RESULT_DIR/startup-time.json"
cat "$RESULT_DIR/startup-time.md" >> "$REPORT"

heading "Plain text speed"
hyperfine \
	"$(printf "%q" "$BAT") --language txt --paging=never 'test-src/jquery-3.3.1.js'" \
	--warmup "$WARMUP_COUNT" \
    --export-markdown "$RESULT_DIR/plain-text-speed.md" \
    --export-json "$RESULT_DIR/plain-text-speed.json"
cat "$RESULT_DIR/plain-text-speed.md" >> "$REPORT"

for SRC in test-src/*; do
	filename="$(basename "$SRC")"
	heading "Syntax highlighting speed: \`$filename\`"

	hyperfine --warmup "$WARMUP_COUNT" \
		"$(printf "%q" "$BAT") --style=full --color=always --paging=never $(printf "%q" "$SRC")" \
		--export-markdown "$RESULT_DIR/syntax-highlighting-speed-${filename}.md" \
		--export-json "$RESULT_DIR/syntax-highlighting-speed-${filename}.json"
	cat "$RESULT_DIR/syntax-highlighting-speed-${filename}.md" >> "$REPORT"
done
