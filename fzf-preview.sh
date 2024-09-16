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
			[path]="$1"
		)
		sleep 10m
	)  
}

catimg_previewer () {
	img_width=$(identify "$1" | grep -Eo " [[:digit:]]+ *x *[[:digit:]]+ " | grep -Eo " [[:digit:]]+")
	img_height=$(identify "$1" | grep -Eo " [[:digit:]]+ *x *[[:digit:]]+ " | grep -Eo "[[:digit:]]+ ")
	if (( 2 * FZF_PREVIEW_COLUMNS * img_height > 5 * img_width * FZF_PREVIEW_LINES )); then  
		catimg -r 2 -H "$((2 * FZF_PREVIEW_LINES))" "$1"
	else
		catimg -r 2 -w "$((2 * FZF_PREVIEW_COLUMNS))" "$1"
	fi
}

path=$1
type=$(file -b --mime-type "$path")

if [ -d "$path" ]; then  # directory
	ls --color "$path"
elif [ "$type" == "image/vnd.djvu" ]; then
	 ddjvu -format=tiff -page=1 "$path" "$tmp_file"
	 $image_previewer "$tmp_file"
elif [ "${type:0:5}" == "image" ]; then
	$image_previewer "$path"
elif [ "${type:0:5}" == "video" ]; then
	ffmpegthumbnailer -i "$path" -o "$tmp_file" -s 0 -m 2>/dev/null
	$image_previewer "$tmp_file"
elif [ "$type" == "application/pdf" ]; then
	pdftoppm -singlefile -jpeg "$path" "$tmp_file" 2>/dev/null
	$image_previewer "$tmp_file.jpg"
elif [[ $type == *"epub"* ]]; then
	epub-thumbnailer "$path" "$tmp_file" "1440"
	$image_previewer "$tmp_file"
else  # text and misc
	bat --color always "$path"
fi

rm -f "$tmp_file"
