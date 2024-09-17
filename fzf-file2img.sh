#!/bin/bash

file=$1
image_preview=$2
tmp_file="/tmp/fzf-preview"
img=""  # image path

# File type handling
type=$(file --dereference -b --mime-type "$file")
if [ -d "$file" ]; then  # directory
    ls --color "$file"
elif [ "$type" == "image/vnd.djvu" ]; then
    ddjvu -format=tiff -page=1 "$file" "$tmp_file"
    img="$tmp_file"
elif [ "${type:0:5}" == "image" ]; then
    img="$file"
elif [ "${type:0:5}" == "audio" ]; then
    ffmpeg -y -i "$file" -an -c:v copy "$tmp_file.jpg" 2> /dev/null
    [ $? == 0 ] && img="$tmp_file.jpg"
    [ $? != 0 ] && exiftool "$file"
elif [ "${type:0:5}" == "video" ]; then
    ffmpegthumbnailer -i "$file" -o "$tmp_file" -s 1080 -m 2> /dev/null
    img="$tmp_file"
elif [ "$type" == "application/pdf" ]; then
    pdftoppm -singlefile -jpeg "$file" "$tmp_file" 2> /dev/null
    img="$tmp_file.jpg"
elif [[ $type == *"epub"* ]]; then
    epub-thumbnailer "$file" "$tmp_file" "1440"
    img="$tmp_file"
elif [ "${type:0:4}" == "text" ]; then
    if command -v bat > /dev/null; then
        bat --color always "$file"
    else
        cat "$file"
    fi
else
    file "$file" | fold -sw $((FZF_PREVIEW_COLUMNS-1))
fi

# Definitions of preview methods
kitty_preview () {
    kitty icat --clear --stdin=no --transfer-mode=memory --unicode-placeholder \
    --scale-up --place="$((FZF_PREVIEW_COLUMNS))x$((FZF_PREVIEW_LINES))@0x0" "$1"
}

ueberzug_preview () {
    echo '{"action": "add", "identifier": "fzf", "x": '$FZF_PREVIEW_LEFT', "y": '$FZF_PREVIEW_TOP', "max_width": '$FZF_PREVIEW_COLUMNS', "max_height": '$FZF_PREVIEW_LINES', "path": '"\"$1\""'}' >> /tmp/fzf-ueberzug
}

chafa_preview () {
    chafa -s "$((FZF_PREVIEW_COLUMNS))x$((FZF_PREVIEW_LINES))" "$1"
}

catimg_preview () {
    img_width=$(identify "$1" | grep -Eo " [[:digit:]]+ *x *[[:digit:]]+ " \
                              | grep -Eo " [[:digit:]]+")
    img_height=$(identify "$1" | grep -Eo " [[:digit:]]+ *x *[[:digit:]]+ " \
                               | grep -Eo "[[:digit:]]+ ")
    if ((2 * FZF_PREVIEW_COLUMNS * img_height > 5 * img_width * \
                                                FZF_PREVIEW_LINES )); then
        catimg -r 2 -H "$((2 * FZF_PREVIEW_LINES))" "$1"
    else
        catimg -r 2 -w "$((2 * FZF_PREVIEW_COLUMNS))" "$1"
    fi
}

no_image_preview () {
    file "$1" | fold -sw $((FZF_PREVIEW_COLUMNS-1))
}

# Show image
if [ -n "$img" ]; then
    $image_preview "$img"
elif command -v ueberzug > /dev/null; then
    echo '{"action": "remove", "identifier": "fzf"}' >> /tmp/fzf-ueberzug
elif [[ $KITTY_WINDOW_ID ]]; then
    kitty icat --clear
fi
