#!/usr/bin/env bash

rand=$(mktemp -u XXXXXXXXXX)
fzf_cmd_file="/tmp/fzf-cmd.${rand}"
tmp_img="/tmp/fzf-preview.${rand}"
tmp_ueberzug_fifo=""

# Choose image previewer
if command -v ueberzug >/dev/null; then
    image_preview="ueberzug_preview"
    # Initialize ueberzug (listen to "/tmp/fzf-ueberzug.${rand}")
    tmp_ueberzug_fifo="/tmp/fzf-ueberzug.${rand}"
    rm -f "$tmp_ueberzug_fifo"
    mkfifo "$tmp_ueberzug_fifo"
    if command -v ueberzugpp >/dev/null; then
        tail -f --pid=$$ "$tmp_ueberzug_fifo" 2>/dev/null | ueberzugpp layer --silent &
    else
        tail -f --pid=$$ "$tmp_ueberzug_fifo" 2>/dev/null | ueberzug layer --silent &
    fi
elif [ -n "$KITTY_WINDOW_ID" ]; then
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
    rm -f "$fzf_cmd_file" "$tmp_img" "$tmp_ueberzug_fifo"
}
trap cleanup HUP INT TERM QUIT EXIT

# Choose file opener
opener=""
for cmd in rifle open xdg-open; do
    if command -v "$cmd" >/dev/null; then
        opener="--bind 'enter:become($cmd {+})'"
        break
    fi
done

# Define fzf commands
export FZF_DEFAULT_COMMAND='find -type f'
export FZF_ALTERNATE_COMMAND='find -type d'
if command -v fd >/dev/null; then  # Use fd if available (.fdignore support)
    export FZF_DEFAULT_COMMAND='fd -H --type file'
    export FZF_ALTERNATE_COMMAND='fd -H --type directory'
fi
echo "$FZF_DEFAULT_COMMAND" > "$fzf_cmd_file"

# Set fzf default options (preview cmd, refresh on terminal resize, header, multi-bind to opener)
export FZF_DEFAULT_OPTS=$(
cat <<EOF
--preview '$(dirname "$0")/fzf-file2preview.sh {} "$image_preview" "$cache_dir" "$tmp_img" "$tmp_ueberzug_fifo"'
--bind 'resize:refresh-preview'
--bind 'focus:transform-header:file --brief {}'
--bind '\`:reload(
    # Toggle between file and directory search
    if grep -qxF "$FZF_DEFAULT_COMMAND" "$fzf_cmd_file"; then
        echo "$FZF_ALTERNATE_COMMAND" > "$fzf_cmd_file"
    else
        echo "$FZF_DEFAULT_COMMAND" > "$fzf_cmd_file"
    fi
    . "$fzf_cmd_file"
)'
--multi $opener
EOF
)

# Run fzf
fzf
