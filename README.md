# ***fzf*** with versatile previewing
![Screenshot](screenshot.png)

# Usage
Run the bash script `fzf-preview.sh`. <br />
This chooses an image viewer and calls `fzf` with preview script `fzf-file2preview.sh`.

# Dependencies
`fzf`: [junegunn/fzf](https://github.com/junegunn/fzf)

## Image viewer
`ueberzugpp`: [jstkdng/ueberzugpp](https://github.com/jstkdng/ueberzugpp) (suggested)

Alternatives: <br />
`ueberzug`: [ueber-devel/ueberzug](https://github.com/ueber-devel/ueberzug) <br />
`chafa`: [hpjansson/chafa](https://github.com/hpjansson/chafa) <br />
`catimg`: [posva/catimg](https://github.com/posva/catimg)

Also works within a `kitty` terminal employing `kitty icat`.

## File-to-image converters
audio: `ffmpeg`, `exiftool` <br />
djvu: `ddjvu` <br />
epub: `epub-thumbnailer` <br />
pdf: `pdftoppm` <br />
video: `ffmpegthumbnailer`
