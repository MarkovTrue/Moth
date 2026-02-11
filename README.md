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
* Поддержка форматов `AVIF` `BMP` `GIF` `HEIC` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP`


## Поддерживаемые форматы по типам действий

| Действие | Поддерживаемые форматы |
|---|---|
| Сжатие без потерь (lossless)<br><sub>Удаляются все EXIF/мета данные</sub> | `AVIF` `BMP` `GIF` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP` |
| Сжатие без потерь EXIF (lossless)<br><sub>Сохраняются EXIF/мета данные</sub> | `JPE` `JPEG` `JPG` |
| Сжатие с потерями (lossy)<br><sub>Сжатие без видимых изменений</sub> | `GIF` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP` |
| Сжатие для WEB<br><sub>Более агрессивное сжатие, но щадит градиенты</sub> | `GIF` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP` |
| Изменение палитры<br><sub>Квантование цвета - это способ уменьшить размер<br>изображения за счет уменьшения палитры цветов</sub> | `PNG` |
| Изменить размер<br><sub>Доп параметры есть в файле конфигурации</sub> | `AVIF` `BMP` `GIF` `JFIF` `JPE` `JPEG` `JPG` `PNG` `WEBP` |
| Конвертация в PNG | `AVIF` `BMP` `GIF` `HEIC` `JFIF` `JPE` `JPEG` `JPG` `WEBP` |
| Конвертация в WEBP | `HEIC` `JFIF` `JPE` `JPEG` `JPG` `PNG` |
| Конвертация в JPG | `AVIF` `BMP` `GIF` `HEIC` `JFIF` `PNG` `WEBP` |


## Конфигурация
Команды настраиваются в Moth.ini.
Можно изменить правило перезаписи, названия, иконки или добавить свой пункт.


## 🤝 Поддержка
Баг‑репорты и предложения приветствуются.
Поддержка: [CloudTips](https://pay.cloudtips.ru/p/c4a97b44)


