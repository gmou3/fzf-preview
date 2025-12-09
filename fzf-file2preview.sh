#!/usr/bin/env bash

FILE="$1"                               # fzf search result
IMG_PREVIEW="${2:-generic_preview}"     # preview method
CACHE_DIR="$3"                          # cache directory
TMP_IMG="${4:-/tmp/fzf-preview}"        # location to place extracted image from file
UEBERZUG_FIFO="$5"                      # file to send ueberzug commands
IMG=""                                  # location of final image
MAX_SIZE=$((100 * 1024 * 1024))         # size threshold (100 MB)

# Cross-platform file size retrieval
get_file_size () {
    if stat --version >/dev/null 2>&1; then
        stat -c%s "$1"  # GNU/Linux
    else
        stat -f%z "$1"  # macOS/BSD
    fi
}

# Generate cache key based on modification time and size
get_cache_key() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local mtime=$(stat -f "%m" "$FILE")
        local size=$(stat -f "%z" "$FILE")
    else
        local mtime=$(stat -c "%Y" "$FILE")
        local size=$(stat -c "%s" "$FILE")
    fi
    echo "${mtime}_${size}"
}

# Check if cached image exists
get_cached_image() {
    local cache_file="$CACHE_DIR/$(get_cache_key "$FILE")"

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
    local cache_file="$CACHE_DIR/$(get_cache_key "$FILE")"

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
                file "$FILE"
            } | fold -sw $((FZF_PREVIEW_COLUMNS - 1))
        fi
        return 1
    fi
}

# Definitions of preview methods
kitty_preview () {
    kitty icat --clear --stdin=no --transfer-mode=memory --unicode-placeholder \
    --scale-up --place="$((FZF_PREVIEW_COLUMNS))x$((FZF_PREVIEW_LINES))@0x0" "$1"
}

ueberzug_preview() {
	cat <<-EOF >> "$UEBERZUG_FIFO"
	{"action": "add", "identifier": "fzf", "x": $FZF_PREVIEW_LEFT, "y": $FZF_PREVIEW_TOP, "max_width": $FZF_PREVIEW_COLUMNS, "max_height": $FZF_PREVIEW_LINES, "path": "$1"}
EOF
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

generic_preview () {
    file "$1" | fold -sw $((FZF_PREVIEW_COLUMNS - 1))
    printf "\n"
}

# Check cache for file
if cached_img=$(get_cached_image); then
    IMG="$cached_img"

# Directory
elif [ -d "$FILE" ]; then
    ls "$FILE"

# File handling by type
else
    type=$(file --dereference -b --mime-type "$FILE")

    case "$type" in
        # Images (and DJVU)
        image/*)
            if [ "$type" != "image/vnd.djvu" ]; then
                if magick "$FILE" -auto-orient -resize x1080 "$TMP_IMG" 2> /dev/null; then
                    IMG=$(cache_image "$TMP_IMG")
                else
                    IMG="$FILE"
                fi
            else
                # DJVU
                if cmd_e ddjvu -format=tiff -size=1920x1080 -page=1 "$FILE" "$TMP_IMG"; then
                    IMG=$(cache_image "$TMP_IMG")
                fi
            fi
            ;;

        # Audio
        audio/*)
            if cmd_e ffmpeg -y -i "$FILE" -an -c:v copy "$TMP_IMG.jpg"; then
                mv "$TMP_IMG.jpg" "$TMP_IMG"
                IMG=$(cache_image "$TMP_IMG")
            else
                cmd_e exiftool "$FILE"
            fi
            ;;

        # Video
        video/*)
            if cmd_e ffmpegthumbnailer -i "$FILE" -o "$TMP_IMG" -s 1080 -m; then
                IMG=$(cache_image "$TMP_IMG")
            fi
            ;;

        # PDF
        application/pdf)
            if cmd_e pdftoppm -singlefile -jpeg "$FILE" "$TMP_IMG"; then
                mv "$TMP_IMG.jpg" "$TMP_IMG"
                IMG=$(cache_image "$TMP_IMG")
            fi
            ;;

        # Office documents
        *officedocument.wordprocessingml.document*)
            cmd_e docx2txt "$FILE" -
            ;;

        # OpenDocument text
        *vnd.oasis.opendocument.text*)
            cmd_e odt2txt "$FILE"
            ;;

        # Email
        message/rfc822)
            cmd_e mu view "$FILE"
            ;;

        # EPUB
        *epub*)
            if cmd_e epub-thumbnailer "$FILE" "$TMP_IMG" "1080"; then
                IMG=$(cache_image "$TMP_IMG")
            fi
            ;;

        # Compressed files
        application/zip)
            generic_preview "$FILE"
            if [ "$(get_file_size "$FILE")" -lt "$MAX_SIZE" ]; then
                cmd_e unzip -l "$FILE" && printf "\n"
                cmd_e unzip -p "$FILE"
            fi
            ;;
        application/gzip)
            generic_preview "$FILE"
            if [ "$(get_file_size "$FILE")" -lt "$MAX_SIZE" ]; then
                cmd_e zcat -l "$FILE" && printf "\n"
                cmd_e zcat "$FILE"
            fi
            ;;
        application/x-bzip2)
            generic_preview "$FILE"
            if [ "$(get_file_size "$FILE")" -lt "$MAX_SIZE" ]; then
                cmd_e bzcat "$FILE"
            fi
            ;;
        application/x-xz)
            generic_preview "$FILE"
            if [ "$(get_file_size "$FILE")" -lt "$MAX_SIZE" ]; then
                cmd_e xz -l "$FILE" && printf "\n"
                cmd_e xzcat "$FILE"
            fi
            ;;

        # Binaries
        application/x-executable|application/x-pie-executable|application/x-sharedlib|application/x-object)
            cmd_e readelf -a "$FILE"
            ;;

        # Text files
        text/*)
            if [[ "${FILE: -3}" == ".md" ]]; then
                cmd_e glow --width $((FZF_PREVIEW_COLUMNS - 1)) "$FILE"
            elif command -v bat > /dev/null; then
                bat --color always "$FILE"
            else
                cat "$FILE"
            fi
            ;;

        # Generic fallback
        *)
            generic_preview "$FILE"
            ;;
    esac
fi

# Show image
if [ -n "$IMG" ]; then
    $IMG_PREVIEW "$IMG"
elif command -v ueberzug > /dev/null; then
    echo '{"action": "remove", "identifier": "fzf"}' >> "$UEBERZUG_FIFO"
elif [ -n "$KITTY_WINDOW_ID" ]; then
    kitty icat --clear
fi
