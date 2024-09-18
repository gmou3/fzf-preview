#!/bin/bash

# Choose image previewer
if command -v ueberzug > /dev/null; then
    image_preview="ueberzug_preview"
    # Initialize ueberzug (listen to /tmp/fzf-ueberzug)
    touch /tmp/fzf-ueberzug
    if command -v ueberzugpp > /dev/null; then
        tail -f --pid=$$ /tmp/fzf-ueberzug 2> /dev/null | ueberzugpp layer --silent &
    else
        tail -f --pid=$$ /tmp/fzf-ueberzug 2> /dev/null | ueberzug layer --silent &
    fi
elif [[ $KITTY_WINDOW_ID ]]; then
    image_preview="kitty_preview"
elif command -v chafa > /dev/null; then
    image_preview="chafa_preview"
elif command -v catimg > /dev/null; then
    image_preview="catimg_preview"
else
    image_preview="no_image_preview"
fi

# Setup and run fzf
export FZF_DEFAULT_COMMAND='fd -H -t file'
preview_arg="$(dirname "$0")/fzf-file2img.sh {} $image_preview"
fzf --preview="$preview_arg"  # --multi --bind 'enter:become(rifle {+})'

# Clear last image and remove temporary files
if command -v ueberzug > /dev/null; then
    echo '{"action": "remove", "identifier": "fzf"}' >> /tmp/fzf-ueberzug
fi
rm -f "/tmp/fzf-preview" "/tmp/fzf-preview.jpg" "/tmp/fzf-ueberzug"
