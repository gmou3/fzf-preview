#!/bin/bash

file="$1"                               # fzf search result
image_preview="${2:-no_image_preview}"  # preview method
cache_dir="$3"                          # cache directory
tmp_img="${4:-/tmp/fzf-preview}"        # location to place extracted image from file
tmp_ueberzug_fifo="$5"                  # file to send ueberzug commands
img=""                                  # location of final image

# Generate cache key based on modification time and size
get_cache_key() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local mtime=$(stat -f "%m" "$file")
        local size=$(stat -f "%z" "$file")
    else
        local mtime=$(stat -c "%Y" "$file")
        local size=$(stat -c "%s" "$file")
    fi
    echo "${mtime}_${size}"
}

# Check if cached image exists
get_cached_image() {
    local cache_file="$cache_dir/$(get_cache_key "$file")"

    if [ -f "$cache_file" ]; then
        touch "$cache_file"
        echo "$cache_file"
        return 0
    fi
    return 1
}

# Save image to cache
cache_image() {
    local src_img="$1"
    local cache_file="$cache_dir/$(get_cache_key "$file")"

    if [ -f "$src_img" ]; then
        cp "$src_img" "$cache_file" 2> /dev/null
        echo "$cache_file"
    fi
}

# Error handling function
cmd_e() {
    if "$@" 2> /dev/null; then
        return 0
    else
        if ! command -v "$1" > /dev/null; then
            {
                echo "Preview method unavailable: install $1"
                echo ""
                file "$file"
            } | fold -sw $((FZF_PREVIEW_COLUMNS-1))
        fi
        return 1
    fi
}

# File type handling
type=$(file --dereference -b --mime-type "$file")

# Check cache for file
if cached_img=$(get_cached_image); then
    img="$cached_img"

# Directory
elif [ -d "$file" ]; then
    ls "$file"

# Media
elif [[ "${type:0:5}" == "image" && "$type" != *"djvu"* ]]; then
    if magick "$file" -auto-orient -resize x1080 "$tmp_img" 2> /dev/null; then
        img=$(cache_image "$tmp_img")
    else
        img="$file"
    fi
elif [ "${type:0:5}" == "audio" ]; then
    if cmd_e ffmpeg -y -i "$file" -an -c:v copy "$tmp_img.jpg"; then
        mv "$tmp_img.jpg" "$tmp_img"
        img=$(cache_image "$tmp_img")
    else
        cmd_e exiftool "$file"
    fi
elif [ "${type:0:5}" == "video" ]; then
    if cmd_e ffmpegthumbnailer -i "$file" -o "$tmp_img" -s 1080 -m; then
        img=$(cache_image "$tmp_img")
    fi

# Documents
elif [ "$type" == "application/pdf" ]; then
    if cmd_e pdftoppm -singlefile -jpeg "$file" "$tmp_img"; then
        mv "$tmp_img.jpg" "$tmp_img"
        img=$(cache_image "$tmp_img")
    fi
elif [ "$type" == "image/vnd.djvu" ]; then
    if cmd_e ddjvu -format=tiff -size=1920x1080 -page=1 "$file" "$tmp_img"; then
        img=$(cache_image "$tmp_img")
    fi
elif [[ "$type" == *"officedocument.wordprocessingml.document"* ]]; then
    cmd_e docx2txt "$file" -
elif [[ "$type" == *"vnd.oasis.opendocument.text"* ]]; then
    cmd_e odt2txt "$file"
elif [ "$type" == "message/rfc822" ]; then  # email (.eml)
    cmd_e mu view "$file"
elif [[ "$type" == *"epub"* ]]; then
    if cmd_e epub-thumbnailer "$file" "$tmp_img" "1080"; then
        img=$(cache_image "$tmp_img")
    fi

# Compressed files
elif [ "$type" == "application/zip" ]; then
    cmd_e unzip -l "$file"
elif [ "$type" == "application/gzip" ]; then
    cmd_e zcat "$file"
elif [ "$type" == "application/x-bzip2" ]; then
    cmd_e bzcat "$file"
elif [ "$type" == "application/x-xz" ]; then
    cmd_e xzcat "$file"

# Binaries
elif [[ "$type" == "application/x-executable" || \
        "$type" == "application/x-pie-executable" || \
        "$type" == "application/x-sharedlib" || \
        "$type" == "application/x-object" ]]; then
    cmd_e readelf -a "$file"

# Text
elif [ "${type:0:4}" == "text" ]; then
    if [[ "${file: -3}" == ".md" ]]; then
        cmd_e glow --width $((FZF_PREVIEW_COLUMNS-1)) "$file"
    elif command -v bat > /dev/null; then
        bat --color always "$file"
    else
        cat "$file"
    fi

# Generic
else
    file "$file" | fold -sw $((FZF_PREVIEW_COLUMNS-1))
fi

# Definitions of preview methods
kitty_preview () {
    kitty icat --clear --stdin=no --transfer-mode=memory --unicode-placeholder \
    --scale-up --place="$((FZF_PREVIEW_COLUMNS))x$((FZF_PREVIEW_LINES))@0x0" "$1"
}

ueberzug_preview () {
    echo '{"action": "add", "identifier": "fzf", "x": '$FZF_PREVIEW_LEFT', "y": '$FZF_PREVIEW_TOP', "max_width": '$FZF_PREVIEW_COLUMNS', "max_height": '$FZF_PREVIEW_LINES', "path": '"\"$1\""'}' >> "$tmp_ueberzug_fifo"
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
    file "$file" | fold -sw $((FZF_PREVIEW_COLUMNS-1))
}

# Show image
if [ -n "$img" ]; then
    $image_preview "$img"
elif command -v ueberzug > /dev/null; then
    echo '{"action": "remove", "identifier": "fzf"}' >> "$tmp_ueberzug_fifo"
elif [[ $KITTY_WINDOW_ID ]]; then
    kitty icat --clear
fi
