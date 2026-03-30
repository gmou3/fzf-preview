#!/usr/bin/env bash

TMP_DIR=$(mktemp -d /tmp/fzf-preview.XXXXXXXXXX)
FZF_STATE_FILE="$TMP_DIR/state"
TMP_IMG="$TMP_DIR/preview"
UEBERZUG_FIFO=""

# Choose image previewer
if command -v ueberzug >/dev/null; then
    IMG_PREVIEW="ueberzug_preview"
    # Initialize ueberzug (listen to a fifo)
    UEBERZUG_FIFO="$TMP_DIR/ueberzug-fifo"
    mkfifo "$UEBERZUG_FIFO"
    tail -f --pid=$$ "$UEBERZUG_FIFO" 2>/dev/null | ueberzug layer --silent &
elif [ -n "$KITTY_WINDOW_ID" ]; then
    IMG_PREVIEW="kitty_preview"
elif command -v chafa >/dev/null; then
    IMG_PREVIEW="chafa_preview"
elif command -v catimg >/dev/null; then
    IMG_PREVIEW="catimg_preview"
else
    IMG_PREVIEW="generic_preview"  # no image
fi

# Cache directory setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    CACHE_DIR="$HOME/Library/Caches/fzf-preview"
else
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fzf-preview"
fi
mkdir -p "$CACHE_DIR"

cleanup () {
    # Clear last image
    if [ -p "$UEBERZUG_FIFO" ]; then
        echo '{"action": "remove", "identifier": "fzf"}' >> "$UEBERZUG_FIFO"
    fi
    # Clean up old cache files
    ls -1t "$CACHE_DIR" | tail -n +201 | xargs -I {} rm "${CACHE_DIR}/{}"
    # Remove temporary files
    rm -rf "$TMP_DIR"
}
trap cleanup HUP INT TERM QUIT EXIT

# Choose file opener
opener=""
for cmd in rifle open xdg-open; do
    if command -v "$cmd" >/dev/null; then
        opener="$cmd"
        break
    fi
done

# Define fzf commands
export FZF_DEFAULT_COMMAND='find . -type f'
export FZF_ALTERNATE_COMMAND='find . -type d'
if command -v fd >/dev/null; then  # Use fd if available (.fdignore support)
    export FZF_DEFAULT_COMMAND='fd -H --type file'
    export FZF_ALTERNATE_COMMAND='fd -H --type directory'
fi
echo "file" > "$FZF_STATE_FILE"

# Set fzf default options (preview cmd, refresh on terminal resize, header, multi-bind to opener)
export FZF_DEFAULT_OPTS=$(
cat <<EOF
--with-shell 'bash -c'
--preview '$(dirname "$0")/fzf-file2preview.sh {} "$IMG_PREVIEW" "$CACHE_DIR" "$TMP_IMG" "$UEBERZUG_FIFO"'
--bind 'resize:refresh-preview'
--bind 'focus,load:transform-header:file --brief {}'
--bind '\`:reload(
    # Toggle between file and directory search
    if grep -qxF "file" "$FZF_STATE_FILE"; then
        echo "directory" > "$FZF_STATE_FILE"
        $FZF_ALTERNATE_COMMAND
    else
        echo "file" > "$FZF_STATE_FILE"
        $FZF_DEFAULT_COMMAND
    fi
)'
--multi ${opener:+--bind 'enter:become($opener {+})'}
EOF
)

# Run fzf
fzf
