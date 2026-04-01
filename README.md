# ***fzf*** with versatile previewing
A terminal-based tool for searching and previewing files. Ideal for system-wide searching.

![Screenshot](screenshot.png)

# Usage
Run the bash script `fzf-preview.sh`. This chooses an image viewer and calls `fzf` with preview script `fzf-file2preview.sh`.

**Keys**: Use the backtick (\`) to cycle through `file` and `directory` results. Press `Enter` to open the selection.

# Dependencies
- [fzf](https://github.com/junegunn/fzf)

This is the only critical dependency. The rest expand functionality and can be
added as needed.

## Image viewer
One of the following, given in fallback order:
- [ueberzugpp](https://github.com/jstkdng/ueberzugpp) (suggested, esp. on X11)
- [kitty](https://github.com/kovidgoyal/kitty) (works in `kitty`/`ghostty`
  terminals, employing `kitten icat`)
- [chafa](https://github.com/hpjansson/chafa)
- [catimg](https://github.com/posva/catimg)

## File-to-preview converters

| Media |                      |
|-------|----------------------|
| audio | `ffmpeg`, `exiftool` |
| video | `ffmpegthumbnailer`  |

| Documents   |                    |
|-------------|--------------------|
| djvu        | `ddjvu`            |
| docx        | `docx2txt`         |
| eml (email) | `mu`               |
| epub        | `epub-thumbnailer` |
| markdown    | `glow`             |
| odt         | `odt2txt`          |
| pdf         | `pdftoppm`         |

| Compressed files |         |
|------------------|---------|
| bz2              | `bzcat` |
| gz               | `zcat`  |
| xz               | `xzcat` |
| zip              | `unzip` |
