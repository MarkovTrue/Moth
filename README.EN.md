[Русский](README.md) | [English](README.EN.md)

# <img src="Preview/HeaderIcon.png" width="30" height="36" align="absmiddle" alt=""> Moth - lossless image compression

[![Release](https://img.shields.io/github/v/release/MarkovTrue/Moth?label=Release&color=%238a2be2&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Ik0xMSAyMS43M2EyIDIgMCAwIDAgMiAwbDctNEEyIDIgMCAwIDAgMjEgMTZWOGEyIDIgMCAwIDAtMS0xLjczbC03LTRhMiAyIDAgMCAwLTIgMGwtNyA0QTIgMiAwIDAgMCAzIDh2OGEyIDIgMCAwIDAgMSAxLjczeiIvPjxwYXRoIGQ9Ik0xMiAyMlYxMiIvPjxwb2x5bGluZSBwb2ludHM9IjMuMjkgNyAxMiAxMiAyMC43MSA3Ii8%2BPC9zdmc%2B)](https://github.com/MarkovTrue/Moth/releases) [![Downloads](https://img.shields.io/github/downloads/MarkovTrue/Moth/total?label=Downloads&color=%230078D4&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Ik0yMSAxNXY0YTIgMiAwIDAgMS0yIDJINWEyIDIgMCAwIDEtMi0ydi00Ii8%2BPHBvbHlsaW5lIHBvaW50cz0iNyAxMCAxMiAxNSAxNyAxMCIvPjxsaW5lIHgxPSIxMiIgeDI9IjEyIiB5MT0iMTUiIHkyPSIzIi8%2BPC9zdmc%2B)](https://github.com/MarkovTrue/Moth/releases)

Batch image optimization and conversion in two clicks from the Explorer context menu. Moth works through the queue and shows the result for every file:

![Preview](Preview/Preview.en.png)

The actions for each format are grouped in the Moth submenu:

![Context menu](Preview/Menu.en.png)


## Features
* Works with files and folders from the context menu
* Weekly update check, nothing is downloaded
* Lossless and lossy compression, WEB optimization, palette reduction, conversion, resizing
* Moth picks the tool for every task, and for JPEG it tries several and keeps the smallest result
* The progress window closes by itself after a delay set in the settings, a click on the window cancels closing
* Drag-and-drop support
* The file list updates on the fly: add more files while Moth is working
* Flexible overwrite rules: by default only lossless compression overwrites the file
* Light and dark theme, English and Russian
* Compression formats: `AVIF` `BMP` `GIF` `JFIF` `JPE` `JPEG` `JPG` `JXL` `PNG` `WEBP`
* Conversion formats: `AVIF` `BMP` `GIF` `HEIC` `HEIF` `JFIF` `JPE` `JPEG` `JPG` `JXL` `PNG` `WEBP`


## Installation
1. Unpack the archive to any folder, for example `C:\Program Files\Moth`
2. Run `Settings.exe`, tick "Add Moth to the Explorer context menu" and press OK
3. Right-click an image or a folder, the **Moth** item

To remove Moth from the menu, untick the same box. If you move the Moth folder, open the settings and press OK again.

![Settings](Preview/Settings.en.png)


## Formats and actions

| Action | JPEG | JFIF | PNG | WEBP | JXL | AVIF | GIF | BMP |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Lossless compression**<br><sub>Exif and other metadata are removed, not a single pixel changes</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |
| **Lossless compression, keep Exif** | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |  |  |
| **Lossy compression**<br><sub>No visible changes, the result is saved next to it with `_lossy`</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |
| **Compression for WEB**<br><sub>Stronger, but gentle to gradients, saved with `_web`</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |
| **Palette 512 and 2048 colors**<br><sub>Fewer colors, Hilbert curve dithering</sub> |  |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |  |  |

JPEG means `.jpg`, `.jpeg` and `.jpe` files.

### Conversion

All formats convert to each other, in any direction:

| Format | Files | What you get |
|---|---|---|
| **JPEG** | `.jpg` `.jpeg` `.jpe` | Saved as `.jpg`, transparency is filled with white |
| **JFIF** | `.jfif` | The same JPEG with a JFIF header. From JPEG it is made without re-encoding |
| **PNG** | `.png` | Lossless |
| **WEBP** | `.webp` | Lossless from JPEG, PNG, GIF and BMP, GIF animation is kept |
| **JXL** | `.jxl` | JPEG is converted reversibly, lossless images stay lossless |
| **AVIF** | `.avif` | Quality 85: visually lossless, smaller than the source JPEG |
| **HEIC** | `.heic` `.heif` | Saved as `.heic`, quality 70, 4:2:0 color like iPhone photos |
| **GIF** | `.gif` | 256 colors with dithering, WEBP animation is kept |
| **BMP** | `.bmp` | Uncompressed, transparency is filled with white |

Extensions in one row are the same format, so there is nothing to convert between them. For example, Moth skips `.jpe` to JPG or `.heif` to HEIC.

The menu shows conversion to JPG and PNG right away, the other formats are in the "Convert…" window, see below. Each format gets only the items it supports there.

For GIF and WEBP animation the first frame is converted, except GIF to WEBP and JXL and WEBP to GIF: there the animation is kept.

Colors do not change. If an image has a color profile other than sRGB, such as Display P3 from a phone or Adobe RGB, Moth keeps it when compressing and converting. An sRGB profile is removed: the image looks the same without it. GIF and BMP cannot store a profile, so converting to them turns the colors into sRGB.

JPEG to JXL is lossless and reversible: the file gets about 15–20% smaller, and converting such a JXL back to JPG restores the original JPEG byte for byte.

Empty cells are not an oversight:
* AVIF and HEIC cannot be recompressed without loss: the available tools either change pixels or only drop the color profile
* HEIC is not compressed: it can only be converted to and from
* BMP stores the image uncompressed, lossy BMP makes no sense: convert it to JPG, WEBP or JXL instead
* Animated WEBP is not compressed: cwebp cannot handle animation. Moth reports "not supported", and converting to GIF keeps the animation
* The palette is offered where its result stays lossless: PNG, WEBP and JXL. JPEG and AVIF lose the palette when compressing, and GIF has at most 256 colors anyway


## Choice windows
Items with an ellipsis open a window with a list: "Change palette…", "Convert…", "Resize…".
The list holds only the actions the file format supports. The action runs for all selected files.

![Choice window](Preview/Convert.en.png)

### Resize
The resize window has ready sizes on top, Full HD and 2K are there from the start. Below is the row of your own size and the panel that builds it.

![Resize window](Preview/Resizer.en.png)

* The title and postfix of the row change as you edit the fields. Next time the row holds the last applied size
* The size comes from the fields edited last: typing a percent clears width and height, and the other way round
* "Fit": the whole picture fits into the size. "Fill": the picture covers the size, the extra stays. "Crop": the extra is cut off
* A size that does not enlarge has a `↓` in its title
* Algorithm: "Photo" is Lanczos, "Graphics" is Catrom, "Pixels" is Point

The result is saved next to the original, with a postfix by size: `_per50`, `_res1920x1080`, `_res1280x`.


## Settings
Language, theme, auto close and context menu options are in the settings window: `Settings.exe` or the gear in the Moth window.

Everything else is in `Moth.ini`: the menu for every format, titles, icons, overwrite rule (`FilePostfix`), your own actions.
For example, you can add a 4096-color palette. After editing the file by hand, open the settings window and press OK to update the context menu.

### Update check
Once a week Moth sends a single request to [GitHub releases](https://github.com/MarkovTrue/Moth/releases) to learn the latest version number. Nothing is downloaded or sent anywhere.
If a new version is out, the window title gets a mark, the gear starts blinking, and the settings show a download link. The check can be turned off or run by hand in the settings.


## Moth uses
Everything is already in the archive, in the `Apps` folder:

* [`pingo 1.27.3`](https://css-ig.net/pingo) – PNG: lossless, lossy and WEB compression
* [`jpegoptim 1.5.6`](https://github.com/tjko/jpegoptim) – JPEG and JFIF: lossless, lossy and WEB compression
* [`ECT 0.9.5`](https://github.com/fhanau/Efficient-Compression-Tool) – JPEG: a second lossless attempt, the smaller file wins
* [`jpegtran 10`](http://jpegclub.org/jpegtran/) – JPEG: lossless rotation by the Exif tag
* [`cwebp 1.6.0`](https://developers.google.com/speed/webp/docs/cwebp) – WEBP: compression and conversion to WEBP
* [`libjxl 0.12.0`](https://github.com/libjxl/libjxl) – JXL: compression, conversion to JXL and back, JPEG is restored byte for byte
* [`gifsicle 1.95`](https://www.lcdf.org/gifsicle/) – GIF: lossless, lossy and WEB compression
* [`ImageWorsener 1.3.5`](https://entropymine.com/imageworsener/) – BMP: lossless compression
* [`libheif 1.23.4`](https://github.com/strukturag/libheif) – conversion to HEIC, x265 encoder
* [`ImageMagick 7.1.2-31`](https://imagemagick.org) – conversion, palette, AVIF and reading HEIC

After conversion and palette reduction the result is squeezed by the same tool as in lossless compression.


## ⚠️ Antivirus
Moth is written in AutoIt, and some antivirus software may flag the exe files as suspicious.
This is a known false positive for programs compiled from AutoIt, not a virus.

* The source code is open – you can review it and build the program yourself
* The files are not packed with UPX and not obfuscated
* If your antivirus complains – check the file on [VirusTotal](https://www.virustotal.com) and add the Moth folder to exclusions
* It helps to report the false positive to the antivirus vendor, for example [Microsoft](https://www.microsoft.com/en-us/wdsi/filesubmission)


## 🤝 Support
Bug reports and suggestions are welcome. If something was compressed wrong, set `Log=1` in `Moth.ini`
and attach the log `%TEMP%\Moth\Moth.log` to your report.

Support the project: [CloudTips](https://pay.cloudtips.ru/p/c4a97b44)
