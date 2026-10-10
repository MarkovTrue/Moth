[Русский](README.md) | [English](README.EN.md)

# <img src="Preview/HeaderIcon.png" width="30" height="36" align="absmiddle" alt=""> Moth - image compression and conversion

[![Release](https://img.shields.io/github/v/release/MarkovTrue/Moth?label=Release&color=%238a2be2&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Ik0xMSAyMS43M2EyIDIgMCAwIDAgMiAwbDctNEEyIDIgMCAwIDAgMjEgMTZWOGEyIDIgMCAwIDAtMS0xLjczbC03LTRhMiAyIDAgMCAwLTIgMGwtNyA0QTIgMiAwIDAgMCAzIDh2OGEyIDIgMCAwIDAgMSAxLjczeiIvPjxwYXRoIGQ9Ik0xMiAyMlYxMiIvPjxwb2x5bGluZSBwb2ludHM9IjMuMjkgNyAxMiAxMiAyMC43MSA3Ii8%2BPC9zdmc%2B)](https://github.com/MarkovTrue/Moth/releases) [![Downloads](https://img.shields.io/github/downloads/MarkovTrue/Moth/total?label=Downloads&color=%230078D4&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Ik0yMSAxNXY0YTIgMiAwIDAgMS0yIDJINWEyIDIgMCAwIDEtMi0ydi00Ii8%2BPHBvbHlsaW5lIHBvaW50cz0iNyAxMCAxMiAxNSAxNyAxMCIvPjxsaW5lIHgxPSIxMiIgeDI9IjEyIiB5MT0iMTUiIHkyPSIzIi8%2BPC9zdmc%2B)](https://github.com/MarkovTrue/Moth/releases)

A utility for batch image optimization and conversion in two clicks from the Explorer context menu. Moth works through the queue and shows the result for every file.

![Preview](Preview/Preview.en.png)

The choice of actions may differ from format to format because of its features.

![Context menu](Preview/Menu.en.png)

## Features
* Works with files and folders from the context menu
* Lossless and lossy compression, palette, conversion, resizing
* The progress window closes automatically, a click on the window cancels closing
* The file list updates on the fly, you can add to the queue while Moth is working
* Light and dark theme, English and Russian, update check
* Overwrite settings, by default the file is overwritten only by lossless compression
* Drag-and-drop support
* The color profile is always kept, except sRGB, the image does not change without it
* The orientation tag is respected by every action, a photo never ends up on its side
* Compression formats: `AVIF` `BMP` `GIF` `JFIF` `JPE` `JPEG` `JPG` `JXL` `PNG` `TIF` `TIFF` `WEBP`
* Conversion formats: `AVIF` `BMP` `GIF` `HEIC` `HEIF` `JFIF` `JPE` `JPEG` `JPG` `JXL` `PNG` `TIF` `TIFF` `WEBP`

## Formats and actions

| Action | &nbsp;JPEG&nbsp; | &nbsp;&nbsp;JFIF&nbsp;&nbsp; | &nbsp;PNG&nbsp;&#8239; | WEBP&#8239; | &nbsp;&nbsp;JXL&nbsp;&nbsp;&#8239; | &nbsp;AVIF&nbsp;&#8239; | &nbsp;&nbsp;GIF&nbsp;&nbsp;&#8239; | &nbsp;BMP&nbsp;&#8239; | &nbsp;TIFF&nbsp;&#8239; |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Lossless compression**<br><sub>Compression algorithms are tried to reduce the size. Exif and metadata are removed too.</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |
| **Lossless, keep Exif / Meta**<br><sub>The same, but Exif and metadata are kept.</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |  |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |
| **Lossy compression**<br><sub>Careful compression with no visible changes.</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |  |
| **Compression for WEB**<br><sub>Stronger compression, but gentle to gradients.</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |  |
| **Palette change**<br><sub>Fewer colors to reduce the size. Hilbert curve dithering.</sub> |  |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |  |  |
| **Resize**<br><sub>Percent, width and height, your own presets. Scaling modes and resampling filters.</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Yes" title="Yes"> |

#### Empty cells are normal:

* AVIF pixels cannot be recompressed losslessly, lossless compression only removes Exif and XMP, the profile stays.<br>
 A palette change makes no sense for AVIF, the file comes out bigger than the source.
* BMP stores the image uncompressed, lossy BMP makes no sense, converting is better.
* A palette won't shrink JPEG or AVIF, and compression blurs the colors back into thousands of shades.
* GIF is limited to 256 colors, so its palette change offers only 64 and 128.
* TIFF is a storage format, it needs neither lossy compression nor a palette. For the web, convert it.

## Conversion

All formats convert to each other, in any direction.<br>
Conversion to JPG, PNG and WEBP is in the menu by default.

| Format | Files | Details |
|---|---|---|
| **JPEG** | `.jpg` `.jpeg` `.jpe` | Always saved as `.jpg`, transparency is filled with white |
| **JFIF** | `.jfif` | The same JPEG with a JFIF header. From JPEG it is made without re-encoding |
| **PNG** | `.png` | Lossless |
| **WEBP** | `.webp` | Lossless from JPEG, PNG, GIF and BMP, GIF animation is kept |
| **JXL** | `.jxl` | JPEG is converted reversibly, lossless images stay lossless |
| **AVIF** | `.avif` | Quality 85: visually lossless, smaller than the source JPEG |
| **HEIC** | `.heic` | Quality 70, 4:2:0 color like iPhone photos |
| **HEIF** | `.heif` | The same HEIC under another extension |
| **GIF** | `.gif` | 256 colors with dithering, WEBP animation is kept |
| **BMP** | `.bmp` | Uncompressed, transparency is filled with white |
| **TIFF** | `.tif` `.tiff` | Lossless, Zip compression, the profile and transparency are kept |

#### Notes

* HEIC and HEIF with the HEVC codec convert to each other losslessly, only the extension changes.
* HEIF with another codec, AV1 for example, is encoded to HEIC anew.
* Converting a GIF or WEBP to a non-animated format keeps only the first frame.
* A multi-page TIFF converts its first page, CMYK goes to RGB through the profile.

## More about JPEG

The Exif orientation is respected by every action, a photo never ends up on its side.
* Compression with Exif keeps the tag, the viewer rotates the image.
* Compression without Exif rotates the JPEG losslessly, without re-encoding.
* If it cannot be rotated losslessly, the tag stays in the file.
* Conversion and resizing save the image already rotated.

Progressive JPEG is chosen automatically.
* Compression for WEB always saves a progressive JPEG.
* Other compression and conversion to JPEG pick the smaller of two variants.

## More about TIFF

* Compression rewrites all pages losslessly, the file is saved only if it got smaller.
* Pure black-and-white images without gray shades, such as scanned documents, are also tried with fax compression. It is often several times smaller, the smaller file is kept.
* Photoshop layers are not lost. Resizing such a file without losing the layers is impossible, it is skipped.
* Professional TIFFs with special color storage are not supported, such as HDR, scientific and astronomy images, print files in Lab color.

## Usage
1. Unpack the archive to any folder, for example `D:\Portable\Moth`
2. Run `Settings.exe`, tick "Add to the Explorer context menu" and press "OK"<br>
  The `Moth` item appears in the Explorer context menu

To remove Moth from the menu, untick the same box. If you move the Moth folder, open the settings and press "OK" again.

![Settings](Preview/Settings.en.png)

## Menu windows
### Extended list
An item with an ellipsis opens a list of the actions the file format supports.

![Choice window](Preview/Convert.en.png)

The pin to the right of an action pins it to the Explorer menu, each format has its own pinned items.<br>`Ctrl` + **Click** - runs the action without closing the window. `Shift` + **Drag** - moves the window.

### Resize
The window has ready presets on top, below them the row of your own size and the panel that builds it.

![Resize window](Preview/Resizer.en.png)

The title and postfix of the row change on the fly. The last applied action is kept.<br>
A size that does not enlarge has a `↓` arrow in its title.

When both width and height are set, the mode decides how the image fits the frame:
* **Fit** - the whole image is inside the size, the proportions are kept
* **Fill** - the image covers the size, the excess stays, postfix `_fill`
* **Crop** - the image covers the size, the excess is cut off, postfix `_crop`

The bottom row is the smoothing mode, pick it by what the picture holds:

| Button | Filter | Best for | Postfix |
|---|---|---|---|
| **Photo** | Lanczos | The base, a universal filter for most cases. | - |
| **Graphics** | Catmull-Rom | Screenshots, diagrams, text, logos. Almost as sharp, but with less halo around letters and lines, flat fills stay even. | `_vec` |
| **Pixels** | Point | Good for pixel art and small icons. Neighbor pixels are not blended, edges stay stepped. Best when enlarging by a whole number: 200% or 300%. | `_pix` |

The result is saved next to the original, with a postfix by size, mode and smoothing: `_per50`, `_res1920x1080`, `_res800x800_crop_vec`.

## Moth uses
Everything is already in the archive, in the `Apps` folder:

* [`pingo 1.27.3`](https://css-ig.net/pingo) – PNG: lossless, lossy and WEB compression
* [`jpegoptim 1.5.6`](https://github.com/tjko/jpegoptim) – JPEG and JFIF: lossless, lossy and WEB compression
* [`ECT 0.9.5`](https://github.com/fhanau/Efficient-Compression-Tool) – JPEG: a second lossless attempt, the smaller file wins
* [`jpegtran 10`](http://jpegclub.org/jpegtran/) – JPEG: lossless rotation by the Exif tag
* [`cwebp 1.6.0`](https://developers.google.com/speed/webp/docs/cwebp) – WEBP: compression and conversion to WEBP
* [`libjxl 0.12.0`](https://github.com/libjxl/libjxl) – JXL: compression, conversion to JXL and back, JPEG is restored byte for byte
* [`gifsicle 1.95`](https://www.lcdf.org/gifsicle/) – GIF: lossless, lossy and WEB compression, squeezes the palette result
* [`ImageWorsener 1.3.5`](https://entropymine.com/imageworsener/) – BMP: lossless compression
* [`libheif 1.23.4`](https://github.com/strukturag/libheif) – conversion to HEIC and HEIF, x265 encoder
* [`ImageMagick 7.1.2-31`](https://imagemagick.org) – conversion, palette, resizing, AVIF, TIFF and reading HEIC and HEIF
* [`ExifTool 13.59`](https://exiftool.org/) – TIFF: carries Exif, the color profile and Photoshop layers over when compressing. AVIF: removes Exif and XMP

After conversion and palette reduction the result is squeezed by the same tool as in lossless compression.

## Antivirus
Moth is written in AutoIt, and some antivirus software may flag the exe files as suspicious.<br>
This is a [known false positive](https://www.autoitscript.com/wiki/AutoIt_and_Malware) for programs compiled from AutoIt.

## 🤝 Support
Bug reports and suggestions are welcome.
Support: [CloudTips](https://pay.cloudtips.ru/p/c4a97b44).
