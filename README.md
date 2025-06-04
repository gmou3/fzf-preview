# ***fzf*** with versatile previewing
![Screenshot](screenshot.png)

# Usage
Run the bash script `fzf-preview.sh`. <br />
This chooses an image viewer and calls `fzf` with preview script `fzf-file2preview.sh`.

# Dependencies
`fzf`: [junegunn/fzf](https://github.com/junegunn/fzf)

This is the only critical dependency. The rest expand functionality and can be
added as needed.

## Image viewer
`ueberzugpp`: [jstkdng/ueberzugpp](https://github.com/jstkdng/ueberzugpp) (suggested)

Alternatives: <br />
`ueberzug`: [ueber-devel/ueberzug](https://github.com/ueber-devel/ueberzug) <br />
`chafa`: [hpjansson/chafa](https://github.com/hpjansson/chafa) <br />
`catimg`: [posva/catimg](https://github.com/posva/catimg)

Also works within a `kitty` terminal employing `kitty icat`.

## File-to-preview converters

### Media
audio: `ffmpeg`, `exiftool` <br />
video: `ffmpegthumbnailer`

### Documents
djvu: `ddjvu` <br />
docx: `docx2txt` <br />
eml (email): `mu` <br />
epub: `epub-thumbnailer` <br />
odt: `odt2txt` <br />
pdf: `pdftoppm`

### Compressed files
bz2: `bzcat` <br />
gz: `unzip` <br />
xz: `xzcat` <br />
zip: `zcat`
