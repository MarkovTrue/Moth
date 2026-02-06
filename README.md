# 🦋 Moth - сжатие изображений без потерь

[![GitHub Release](https://img.shields.io/github/release/MarkovTrue/Moth)](https://github.com/MarkovTrue/Moth/releases) [![Downloads](https://img.shields.io/github/downloads/MarkovTrue/Moth/latest/total?label=downloads&color=blue)](https://github.com/MarkovTrue/Moth/releases)

Утилита для пакетной оптимизации или конвертации за два клика из контекстного меню.


## Возможности
* Работа с файлами и папками из контекстного меню
* Сжатие изображений без потерь и с потерями, оптимизация для WEB, конвертация
* Окно прогресса закрывается автоматически, активация окна отменяет закрытие
* Поддержка перетаскивания drag-and-drop
* Список файлов обновляется динамически, можно дополнять очередь пока идет работа
* Гибкая настройка перезаписи: по умолчанию файл перезаписывается только при сжатии без потерь
* Поддержка форматов: `AVIF` `BMP` `GIF` `HEIC` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP`


## Поддерживаемые форматы по типам действий

* Сжатие без потерь (lossless) - удаляется все EXIF/мета данные `AVIF` `BMP` `GIF` `HEIC` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP`
* Сжатие с потерями (lossy) - сжатие без видимых изменений `GIF` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP`
* Сжатие для WEB - более арессивное сжатие, но щадит градиенты `GIF` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP`
Изменить размер - доп параметры в в файле конфигурации `AVIF` `BMP` `GIF` `HEIC` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP`
Изменение палитры (color quantization) - квантование цвета это способ уменьшить размер изображения за счет уменьшения палитры цветов: `PNG`
Конвертация в PNG `AVIF` `BMP` `GIF` `HEIC` `JFIF` `JPE` `JPEG` `JPG` `WEBP`
Конвертация в WEBP `JFIF` `JPE` `JPEG` `JPG` `PNG`
Конвертация в JPG `AVIF` `BMP` `GIF` `HEIC` `JFIF` `PNG` `WEBP`


## Конфигурация
Команды настраиваются в Moth.ini
Можно изменить правило перезаписи, названия, иконки или добавить свой пункт.


## 🤝 Поддержка
Баг‑репорты и предложения приветствуются.
Поддержка: [CloudTips](https://pay.cloudtips.ru/p/c4a97b44)
