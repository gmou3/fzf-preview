#!/bin/bash

tmp_file="/tmp/fzf-preview"
image_previewer="ueberzug_previewer"

ueberzug_previewer () {
	ueberzug layer --parser bash 0< <(
		declare -Ap add_command=(
			[action]="add"
			[identifier]="fzf"
			[x]="$FZF_PREVIEW_LEFT"
			[y]="$FZF_PREVIEW_TOP"
			[scaler]="fit_contain"
			[max_width]="$FZF_PREVIEW_COLUMNS"
			[max_height]="$FZF_PREVIEW_LINES"
			[path]="$tmp_file"
		)
		sleep 1d
	)  
}

catimg_previewer () {
	img_width=$(identify "$tmp_file" | grep -Eo " [[:digit:]]+ *x *[[:digit:]]+ " | grep -Eo " [[:digit:]]+")
	img_height=$(identify "$tmp_file" | grep -Eo " [[:digit:]]+ *x *[[:digit:]]+ " | grep -Eo "[[:digit:]]+ ")
	if (( 2 * FZF_PREVIEW_COLUMNS * img_height > 5 * img_width * FZF_PREVIEW_LINES )); then  
		catimg -r 2 -H "$((2 * FZF_PREVIEW_LINES))" "$tmp_file"
	else
		catimg -r 2 -w "$((2 * FZF_PREVIEW_COLUMNS))" "$tmp_file"
	fi
}

path=$1
type=$(file --mime "$path")

if [ -d "$path" ]; then  # directory
	ls --color "$path"
elif [[ $type == *"image"* ]]; then
	cp "$path" "$tmp_file"
	$image_previewer
elif [[ $type == *"video"* ]]; then
	ffmpegthumbnailer -i "$path" -o "$tmp_file" -s 0 -m 2>/dev/null
	$image_previewer
elif [[ $type == *"pdf"* ]]; then
	pdftoppm -singlefile -jpeg "$path" "$tmp_file" 2>/dev/null
	mv "$tmp_file.jpg" "$tmp_file"
	$image_previewer
elif [[ $type == *"epub"* ]]; then
	epub-thumbnailer "$path" "$tmp_file" "1440"
	$image_previewer
else  # text and misc
	bat --color always "$path"
fi
