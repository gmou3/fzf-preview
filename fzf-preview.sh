#!/usr/bin/env bash

tmp_img=$(mktemp /tmp/fzf-preview.XXXXXXXXXX)
tmp_ueberzug_fifo=""

# Choose image previewer
if command -v ueberzug >/dev/null; then
    image_preview="ueberzug_preview"
    # Initialize ueberzug (listen to /tmp/fzf-ueberzug.XXXXXXXXXX)
    tmp_ueberzug_fifo=$(mktemp /tmp/fzf-ueberzug.XXXXXXXXXX)
    rm -f "$tmp_ueberzug_fifo"
    mkfifo "$tmp_ueberzug_fifo"
    if command -v ueberzugpp >/dev/null; then
        tail -f --pid=$$ "$tmp_ueberzug_fifo" 2>/dev/null | ueberzugpp layer --silent &
    else
        tail -f --pid=$$ "$tmp_ueberzug_fifo" 2>/dev/null | ueberzug layer --silent &
    fi
elif [[ $KITTY_WINDOW_ID ]]; then
    image_preview="kitty_preview"
elif command -v chafa >/dev/null; then
    image_preview="chafa_preview"
elif command -v catimg >/dev/null; then
    image_preview="catimg_preview"
else
    image_preview="no_image_preview"
fi

# Cache directory setup
if [[ "$OSTYPE" == "darwin"* ]]; then
    cache_dir="$HOME/Library/Caches/fzf-preview"
else
    cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/fzf-preview"
fi
mkdir -p "$cache_dir"

cleanup () {
    # Clear last image
    if command -v ueberzug >/dev/null; then
        echo '{"action": "remove", "identifier": "fzf"}' >> "$tmp_ueberzug_fifo"
    fi
    # Clean up old cache files
    ls -1t "$cache_dir" | tail -n +201 | xargs -I {} rm "${cache_dir}/{}"
    # Remove temporary files
    [[ -n "$tmp_img" ]] && rm -f "$tmp_img"
    [[ -n "$tmp_ueberzug_fifo" ]] && rm -f "$tmp_ueberzug_fifo"
}
trap cleanup HUP INT TERM QUIT EXIT

# Set fzf to use fd if available (.fdignore support)
if command -v fd >/dev/null; then
    export FZF_DEFAULT_COMMAND='fd -H --type file'
fi

# Choose file opener
opener=""
for cmd in rifle open xdg-open; do
    if command -v "$cmd" >/dev/null; then
        opener="--bind 'enter:become($cmd {+})'"
        break
    fi
done

# Set fzf default options (preview cmd, refresh on terminal resize, header, multi-bind to opener)
export FZF_DEFAULT_OPTS=$(
cat <<EOF
--preview '$(dirname "$0")/fzf-file2preview.sh {} "$image_preview" "$cache_dir" "$tmp_img" "$tmp_ueberzug_fifo"'
--bind 'resize:refresh-preview'
--bind 'focus:transform-header:file --brief {}'
--multi $opener
EOF
)

# Run fzf
fzf
