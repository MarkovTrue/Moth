[Русский](README.md) | [English](README.EN.md)

# <img src="Preview/HeaderIcon.png" width="30" height="36" align="absmiddle" alt=""> Moth - сжатие изображений без потерь

[![Release](https://img.shields.io/github/v/release/MarkovTrue/Moth?label=Release&color=%238a2be2&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Ik0xMSAyMS43M2EyIDIgMCAwIDAgMiAwbDctNEEyIDIgMCAwIDAgMjEgMTZWOGEyIDIgMCAwIDAtMS0xLjczbC03LTRhMiAyIDAgMCAwLTIgMGwtNyA0QTIgMiAwIDAgMCAzIDh2OGEyIDIgMCAwIDAgMSAxLjczeiIvPjxwYXRoIGQ9Ik0xMiAyMlYxMiIvPjxwb2x5bGluZSBwb2ludHM9IjMuMjkgNyAxMiAxMiAyMC43MSA3Ii8%2BPC9zdmc%2B)](https://github.com/MarkovTrue/Moth/releases) [![Downloads](https://img.shields.io/github/downloads/MarkovTrue/Moth/total?label=Downloads&color=%230078D4&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCIgZmlsbD0ibm9uZSIgc3Ryb2tlPSJ3aGl0ZSIgc3Ryb2tlLXdpZHRoPSIyIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiPjxwYXRoIGQ9Ik0yMSAxNXY0YTIgMiAwIDAgMS0yIDJINWEyIDIgMCAwIDEtMi0ydi00Ii8%2BPHBvbHlsaW5lIHBvaW50cz0iNyAxMCAxMiAxNSAxNyAxMCIvPjxsaW5lIHgxPSIxMiIgeDI9IjEyIiB5MT0iMTUiIHkyPSIzIi8%2BPC9zdmc%2B)](https://github.com/MarkovTrue/Moth/releases)

Утилита для пакетной оптимизации и конвертации изображений за два клика из контекстного меню проводника. Moth обрабатывает очередь и показывает итог по каждому файлу:

![Превью](Preview/Preview.png)

Действия для каждого формата собраны в подменю Moth:

![Контекстное меню](Preview/Menu.png)


## Возможности
* Работа с файлами и папками из контекстного меню
* Проверка обновлений раз в неделю, без скачивания
* Сжатие изображений без потерь и с потерями, оптимизация для WEB, палитра, конвертация
* Для каждой задачи Moth сам выбирает утилиту, а для JPEG пробует несколько и оставляет лучший результат
* Окно прогресса закрывается автоматически, время задаётся в настройках, клик по окну отменяет закрытие
* Поддержка перетаскивания drag-and-drop
* Список файлов обновляется динамически, очередь можно дополнять, пока идёт работа
* Гибкая настройка перезаписи: по умолчанию файл перезаписывается только при сжатии без потерь
* Светлая и тёмная тема, русский и английский язык
* Форматы для сжатия: `AVIF` `BMP` `GIF` `JFIF` `JPE` `JPEG` `JPG` `JXL` `PNG` `WEBP`
* Форматы для конвертации: `AVIF` `BMP` `GIF` `HEIC` `HEIF` `JFIF` `JPE` `JPEG` `JPG` `JXL` `PNG` `WEBP`


## Установка
1. Распакуйте архив в удобную папку, например `C:\Program Files\Moth`
2. Запустите `Settings.exe`, отметьте «Добавить Moth в контекстное меню проводника» и нажмите «ОК»
3. Щёлкните правой кнопкой по картинке или папке, пункт **Moth**

Чтобы убрать Moth из меню, снимите ту же галочку. Если папку с Moth перенести, откройте настройки и снова нажмите «ОК».

![Настройки](Preview/Settings.png)


## Форматы и действия

| Действие | JPEG | JFIF | PNG | WEBP | JXL | AVIF | GIF | BMP |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **Сжатие без потерь**<br><sub>Удаляются Exif и прочие метаданные, картинка не меняется ни на пиксель</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> |
| **Сжатие без потерь Exif**<br><sub>То же, но Exif-данные сохраняются</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> |  |  |  |
| **Сжатие с потерями**<br><sub>Без видимых изменений, результат рядом с `_lossy`</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> |  |
| **Сжатие для WEB**<br><sub>Агрессивнее, но щадит градиенты, результат рядом с `_web`</sub> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> |  |
| **Палитра 512 и 2048 цветов**<br><sub>Уменьшение числа цветов, дизеринг по кривой Гильберта</sub> |  |  | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> | <img src="Preview/Yes.svg" width="16" height="16" alt="Да" title="Да"> |  |  |  |

### Конвертация

Все форматы конвертируются друг в друга, в любую сторону:

| Формат | Файлы | Как получается результат |
|---|---|---|
| **JPEG** | `.jpg` `.jpeg` `.jpe` | Сохраняется как `.jpg`, прозрачность заливается белым |
| **JFIF** | `.jfif` | Тот же JPEG с заголовком JFIF. Из JPEG получается без перекодирования |
| **PNG** | `.png` | Без потерь |
| **WEBP** | `.webp` | Из JPEG, PNG, GIF и BMP без потерь, анимация GIF сохраняется |
| **JXL** | `.jxl` | JPEG переводится обратимо, картинки без потерь остаются без потерь |
| **AVIF** | `.avif` | Качество 85: на глаз без потерь, файл меньше исходного JPEG |
| **HEIC** | `.heic` `.heif` | Сохраняется как `.heic`, качество 70, цвет 4:2:0, как у снимков iPhone |
| **GIF** | `.gif` | 256 цветов с дизерингом, анимация WEBP сохраняется |
| **BMP** | `.bmp` | Без сжатия, прозрачность заливается белым |

Расширения из одной строки - один формат, конвертировать между ними нечего. Например, `.jpe` в JPG или `.heif` в HEIC Moth пропустит.

Конвертация в JPG и PNG стоит в меню сразу, остальные форматы собраны во вложенном меню «Конвертировать ▸». В нём у каждого формата только те пункты, что ему доступны.

У анимации GIF и WEBP в другой формат конвертируется первый кадр, кроме GIF в WEBP и JXL и WEBP в GIF: там анимация сохраняется.

Цвет не меняется. Если у картинки цветовой профиль не sRGB, например Display P3 с телефона или Adobe RGB, Moth сохраняет его при сжатии и конвертации. Профиль sRGB удаляется: картинка без него выглядит так же. GIF и BMP профиль не хранят, поэтому при конвертации в них цвет переводится в sRGB.

JPEG в JXL переводится без потерь и обратимо: файл меньше примерно на 15–20%, а конвертация такого JXL обратно в JPG возвращает исходный JPEG байт в байт.

Пустые клетки - не недоработка:
* AVIF и HEIC без потерь не пережимаются: доступные утилиты либо меняют пиксели, либо только удаляют цветовой профиль
* HEIC не сжимается: в него и из него можно только конвертировать
* BMP хранит картинку без сжатия, сжимать его с потерями бессмысленно: лучше конвертировать в JPG, WEBP или JXL
* Анимированный WEBP не сжимается: cwebp не умеет анимацию. Moth сообщит «не поддерживается», а сохранить анимацию можно конвертацией в GIF
* Палитра есть там, где её результат остаётся без потерь: PNG, WEBP и JXL. В JPEG и AVIF палитра теряется при сжатии, у GIF она и так не больше 256 цветов


## Настройки
Язык, тема, автозакрытие окна и параметры контекстного меню меняются в окне настроек: `Settings.exe` или шестерёнка в окне Moth.

Всё остальное - в `Moth.ini`: состав меню для каждого формата, названия, иконки, правило перезаписи (`FilePostfix`), свои действия.
Например, можно добавить палитру 256 цветов. После ручной правки откройте окно настроек и нажмите «ОК», чтобы обновить контекстное меню.

### Проверка обновлений
Раз в неделю Moth отправляет один запрос к [релизам на GitHub](https://github.com/MarkovTrue/Moth/releases) и узнаёт номер последней версии. Ничего не скачивается и никуда не отправляется.
Если вышла новая версия, в заголовке окна появится пометка, шестерёнка начнёт мигать, а в настройках будет ссылка на загрузку. Проверку можно выключить или запустить вручную в настройках.


## Moth использует
Всё уже в архиве, в папке `Apps`:

* [`pingo 1.27.3`](https://css-ig.net/pingo) – PNG: сжатие без потерь, с потерями и для WEB
* [`jpegoptim 1.5.6`](https://github.com/tjko/jpegoptim) – JPEG и JFIF: сжатие без потерь, с потерями и для WEB
* [`ECT 0.9.5`](https://github.com/fhanau/Efficient-Compression-Tool) – JPEG: второй вариант сжатия без потерь, остаётся меньший файл
* [`jpegtran 10`](http://jpegclub.org/jpegtran/) – JPEG: поворот по Exif-тегу без потерь
* [`cwebp 1.6.0`](https://developers.google.com/speed/webp/docs/cwebp) – WEBP: сжатие и конвертация в WEBP
* [`libjxl 0.12.0`](https://github.com/libjxl/libjxl) – JXL: сжатие, конвертация в JXL и обратно, JPEG восстанавливается байт в байт
* [`gifsicle 1.95`](https://www.lcdf.org/gifsicle/) – GIF: сжатие без потерь, с потерями и для WEB
* [`ImageWorsener 1.3.5`](https://entropymine.com/imageworsener/) – BMP: сжатие без потерь
* [`libheif 1.23.4`](https://github.com/strukturag/libheif) – конвертация в HEIC, кодировщик x265
* [`ImageMagick 7.1.2-31`](https://imagemagick.org) – конвертация, палитра, AVIF и чтение HEIC

После конвертации и палитры итог дожимается той же утилитой, что и при сжатии без потерь.


## ⚠️ Антивирусы
Moth написан на AutoIt, и некоторые антивирусы могут помечать exe-файлы как подозрительные.
Это известная проблема ложных срабатываний на программы, скомпилированные из AutoIt, а не вирус.

* Исходный код открыт – можно проверить его и собрать программу самостоятельно
* Файлы не упакованы UPX и не обфусцированы
* Если антивирус ругается – проверьте файл на [VirusTotal](https://www.virustotal.com) и добавьте папку Moth в исключения
* О ложном срабатывании полезно сообщить разработчику антивируса, например [Microsoft](https://www.microsoft.com/en-us/wdsi/filesubmission)


## 🤝 Поддержка
Баг‑репорты и предложения приветствуются. Если что-то сжалось не так, включите `Log=1` в `Moth.ini`
и приложите журнал `%TEMP%\Moth\Moth.log` к сообщению.

Поддержка: [CloudTips](https://pay.cloudtips.ru/p/c4a97b44)
