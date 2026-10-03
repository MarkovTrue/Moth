# BuildMenuIcons.py - иконки пунктов контекстного меню и форматов для Themes/Light и Themes/Dark.
# Имя файла - ключ рисунка в PascalCase: resize_down -> ResizeDown.ico, format_jpeg -> FormatJpeg.ico.
#
# Рисунки - вектор в координатах сетки 16x16 (целое число = граница пикселя). Каждый кадр
# (SIZES) рендерится в своём размере с суперсэмплингом и усреднением блоков: в кадре 16 прямые
# края лежат на границах пикселей и остаются чёткими, сглаживаются только диагонали и скругления.
# Глифы значков и подписи форматов в кадре 16 - пиксельные сетки с полутонами ('#' 100%,
# '+' 55%, '-' 25%). В крупных кадрах полутона не рисуются,
# подпись - Bahnschrift Bold Condensed той же высоты, что пиксельный шрифт.
# ICO: кадры меньше PNG_FROM - DIB с маской, остальные - PNG.
#
# Формат - лист с цветной полосой, подпись вырезана в полосе насквозь: на светлом меню
# буквы светлые, на тёмном тёмные. В тёмной теме полоса светлее на DARK_TINT, иначе тёмные
# буквы на тёмной полосе теряются. Цвета полос - как у FastStone Image Viewer (FSIcons.db),
# форматам, которых там нет, взяты цвета из той же палитры.
#
# Новый формат: строка в FORMATS. Подпись в кадре 16 до 16 px шириной: буквы 3 px, G 4 px, M, N и W 5 px,
# I 1 px, между буквами 1 px. Шире - ошибка, подпись нужна короче.
#
# Режимы окна размеров: resize - вписать, fill - заполнить, trim - заполнить и обрезать.
# Серая рамка пунктиром - заданный размер, внутри та же картинка, что у иконок сжатия, на светлом
# небе. Рамка одной высоты, ширина у режимов разная. У каждого режима варианты алгоритма:
# _graphics и _pixels с подписью VEC и PIX по низу, фото - без подписи.
# convert - лист формата синего цвета, подпись - многоточие.
# Folder.ico (Settings.Editor) здесь не рисуется.
# Иконки вспомогательных exe (EXE_ICONS) - серые, в Assets/Icons: в папке программы их не спутать
# с цветным мотыльком Moth.exe и Settings.exe. Launcher - рисунок Fluent, Menu - square-menu из Lucide,
# разложенный по пикселям источников 16, 20 и 24 (SQUARE_MENU). Исходники Fluent - с GitHub
# microsoft/fluentui-system-icons, assets/<Имя>/SVG: там пути в абсолютных командах.
# После сборки скопировать Themes в MothPortable, exe пересобрать.
# Запуск: python Assets/BuildMenuIcons.py [--out <папка>] [--sheet <файл.png>]
import argparse
import io
import os
import re
import struct

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SIZES = (16, 20, 24, 32, 48, 64, 256)
PNG_FROM = 48     # кадры от этого размера в ICO пишутся PNG
DARK_TINT = 0.45  # осветление полосы формата в тёмной теме

THEMES = {
    'light': dict(stroke='5F6B76', sky='D6EAF8'),
    'dark': dict(stroke='B3BCC7', sky='35506A'),
}
TEAL, SUN, BLUE, ORANGE = '26A69A', 'FFB300', '1E88E5', 'EF6C00'

# Файл format_<ключ>.ico: подпись и цвет полосы. Первые девять - форматы Moth
FORMATS = {
    'jpeg': ('JPG', 'E43434'),
    'jfif': ('JFIF', 'E64A19'),
    'png': ('PNG', 'BA34C5'),
    'webp': ('WBP', '4B947C'),
    'jxl': ('JXL', '8429F1'),
    'avif': ('AVIF', 'D08D11'),
    'gif': ('GIF', '048DF2'),
    'bmp': ('BMP', '008000'),
    'heic': ('HEIC', '5B869F'),
    'heif': ('HEIF', '5B869F'),
    'tiff': ('TIF', '5300A6'),
    'psd': ('PSD', 'D08D11'),
    'tga': ('TGA', 'AF5C41'),
    'pcx': ('PCX', '7F7F7F'),
    'wmf': ('WMF', '800040'),
    'emf': ('EMF', '800040'),
    'ico': ('ICO', '048DF2'),
    'svg': ('SVG', 'AF5C41'),
    'jp2': ('JP2', 'B83030'),
    'qoi': ('QOI', '4B947C'),
    'dds': ('DDS', '7F7F7F'),
    'exr': ('EXR', 'A2784F'),
    'hdr': ('HDR', 'A2784F'),
    'dng': ('DNG', '54007C'),
    'cr2': ('CR2', '4B947C'),
    'cr3': ('CR3', '4B947C'),
    'crw': ('CRW', '8429F1'),
    'nef': ('NEF', '5B869F'),
    'nrw': ('NRW', '5B869F'),
    'arw': ('ARW', '8429F1'),
    'srf': ('SRF', '54007C'),
    'sr2': ('SR2', '54007C'),
    'orf': ('ORF', '54007C'),
    'raf': ('RAF', '54007C'),
    'rw2': ('RW2', 'A2784F'),
    'pef': ('PEF', '54007C'),
    'mrw': ('MRW', '54007C'),
}

# ---------- шрифт 3x7 ----------
FONT = {
    'A': ['+#+', '#.#', '#.#', '###', '#.#', '#.#', '#.#'],
    'B': ['##+', '#.#', '#.#', '##+', '#.#', '#.#', '##+'],
    'C': ['+##', '#..', '#..', '#..', '#..', '#..', '+##'],
    'D': ['##+', '#.#', '#.#', '#.#', '#.#', '#.#', '##+'],
    'E': ['###', '#..', '#..', '##.', '#..', '#..', '###'],
    'F': ['###', '#..', '#..', '##.', '#..', '#..', '#..'],
    'G': ['+##+', '#...', '#...', '#.##', '#..#', '#..#', '+##+'],   # с хвостиком, как в Bahnschrift
    'H': ['#.#', '#.#', '#.#', '###', '#.#', '#.#', '#.#'],
    'I': ['#', '#', '#', '#', '#', '#', '#'],
    'J': ['..#', '..#', '..#', '..#', '..#', '#.#', '+#+'],
    'K': ['#.#', '#.#', '#+#', '##.', '#+#', '#.#', '#.#'],
    'L': ['#..', '#..', '#..', '#..', '#..', '#..', '###'],
    'M': ['#+.+#', '##+##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
    'N': ['#+..#', '##..#', '#++.#', '#.#.#', '#.++#', '#..##', '#..+#'],
    'O': ['+#+', '#.#', '#.#', '#.#', '#.#', '#.#', '+#+'],
    'P': ['##+', '#.#', '#.#', '##+', '#..', '#..', '#..'],
    'Q': ['+#+', '#.#', '#.#', '#.#', '#.#', '#+#', '+##'],
    'R': ['##+', '#.#', '#.#', '##+', '#+.', '#.#', '#.#'],
    'S': ['+##', '#..', '#..', '+#+', '..#', '..#', '##+'],
    'T': ['###', '.#.', '.#.', '.#.', '.#.', '.#.', '.#.'],
    'U': ['#.#', '#.#', '#.#', '#.#', '#.#', '#.#', '+#+'],
    'V': ['#.#', '#.#', '#.#', '#.#', '#.#', '+#+', '.#.'],
    'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '#+#+#', '+#.#+'],
    'X': ['#.#', '#.#', '+#+', '.#.', '+#+', '#.#', '#.#'],
    'Y': ['#.#', '#.#', '#.#', '+#+', '.#.', '.#.', '.#.'],
    'Z': ['###', '..#', '.+#', '+#+', '#+.', '#..', '###'],
    '0': ['+#+', '#.#', '#.#', '#.#', '#.#', '#.#', '+#+'],
    '1': ['.#.', '##.', '.#.', '.#.', '.#.', '.#.', '###'],
    '2': ['+#+', '#.#', '..#', '.+#', '+#.', '#..', '###'],
    '3': ['##+', '..#', '..#', '.#+', '..#', '..#', '##+'],
    '4': ['#.#', '#.#', '#.#', '###', '..#', '..#', '..#'],
    '5': ['###', '#..', '#..', '##+', '..#', '..#', '##+'],
    '6': ['+##', '#..', '#..', '##+', '#.#', '#.#', '+#+'],
    '7': ['###', '..#', '..#', '.+#', '.#.', '.#.', '.#.'],
    '8': ['+#+', '#.#', '#.#', '+#+', '#.#', '#.#', '+#+'],
    '9': ['+#+', '#.#', '#.#', '+##', '..#', '..#', '##+'],
}
LABEL_MAX = 16
# Подпись в крупных кадрах; шире LABEL_VEC_MAX единиц сетки сжимается по горизонтали
LABEL_FONT = 'C:/Windows/Fonts/bahnschrift.ttf'
LABEL_AXES = [700, 75]   # Bold Condensed
LABEL_VEC_MAX = 14.5

# Подписи по низу иконки (EXIF, WEB, VEC, PIX): шрифт 4x5, M, V и W 5 px. Вокруг букв
# прозрачная кайма в 1 px, в крупных кадрах - Bahnschrift той же высоты с обводкой-каймой
FONT_PHOTO = {
    'B': ['###+', '#..#', '###.', '#..#', '###+'],
    'C': ['+##+', '#...', '#...', '#...', '+##+'],
    'P': ['###+', '#..#', '###+', '#...', '#...'],
    'V': ['#...#', '#...#', '+#.#+', '.#+#.', '.-#-.'],
    'E': ['####', '#...', '###.', '#...', '####'],
    'F': ['####', '#...', '###.', '#...', '#...'],
    'I': ['#', '#', '#', '#', '#'],
    'W': ['#...#', '#...#', '#.#.#', '#.#.#', '+#.#+'],
    'X': ['#..#', '+##+', '.##.', '+##+', '#..#'],
}
# Узкие буквы: с ними подпись не шире рамки фото (x 1..14)
FONT_PHOTO_NARROW = {
    'E': ['###', '#..', '##.', '#..', '###'],
    'X': ['#.#', '#.#', '.#.', '#.#', '#.#'],
}
# Широкие буквы: PIX с I в засечках и X в 5 px тоже встаёт по краям рамки
FONT_PHOTO_WIDE = {
    'I': ['###', '.#.', '.#.', '.#.', '###'],
    'X': ['#-.-#', '+#-#+', '.+#+.', '+#-#+', '#-.-#'],
}
# Цвета квадратов палитры: жёлтый темнее обычного, светлый сливается с белым меню
PALETTE = ('E53935', 'F9A825', '43A047', '1E88E5')

# Алгоритм ресайза - подпись по низу иконки режима: текст, цвет, узкие и широкие буквы.
# У фото подписи нет. В тёмной теме цвет светлее на LABEL_DARK_TINT, иначе фиолетовый теряется
RESIZE_FILTERS = {'graphics': ('VEC', '8E24AA', 'E', ''), 'pixels': ('PIX', ORANGE, '', 'IX')}
LABEL_DARK_TINT = 0.3


def hexc(h, a=1.0):
    return (int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a)


def tint(h, k):
    return '%02X%02X%02X' % tuple(round(v + (255 - v) * k) for v in (int(h[i:i + 2], 16) for i in (0, 2, 4)))


# ---------- рендер ----------
class Canvas:
    """Холст кадра size x size; фигуры - маски в координатах сетки 16."""

    def __init__(self, size):
        self.size = size
        self.ss = max(4, min(16, 512 // size))   # суперсэмплинг на пиксель кадра
        self.k = size / 16 * self.ss             # точек суперсэмплинга на единицу сетки
        self.n = size * self.ss
        self.c = np.zeros((self.n, self.n, 3), np.float32)   # premultiplied
        self.a = np.zeros((self.n, self.n), np.float32)

    def _draw(self):
        m = Image.new('L', (self.n, self.n), 0)
        return m, ImageDraw.Draw(m)

    @staticmethod
    def _arr(m):
        return np.asarray(m, dtype=np.float32) / 255

    def _box(self, x0, y0, x1, y1):
        k = self.k
        return [x0 * k, y0 * k, x1 * k - 1, y1 * k - 1]

    def rect(self, x0, y0, x1, y1):
        m, d = self._draw()
        d.rectangle(self._box(x0, y0, x1, y1), fill=255)
        return self._arr(m)

    def rrect(self, x0, y0, x1, y1, r):
        m, d = self._draw()
        d.rounded_rectangle(self._box(x0, y0, x1, y1), radius=r * self.k, fill=255)
        return self._arr(m)

    def rrect_stroke(self, x0, y0, x1, y1, r, w=1):
        return np.clip(self.rrect(x0, y0, x1, y1, r) - self.rrect(x0 + w, y0 + w, x1 - w, y1 - w, max(r - w, 0)), 0, 1)

    def ellipse(self, cx, cy, rx, ry=None):
        ry = rx if ry is None else ry
        m, d = self._draw()
        d.ellipse(self._box(cx - rx, cy - ry, cx + rx, cy + ry), fill=255)
        return self._arr(m)

    def ring(self, cx, cy, rx, ry, w=1):
        return np.clip(self.ellipse(cx, cy, rx, ry) - self.ellipse(cx, cy, rx - w, ry - w), 0, 1)

    def poly(self, pts):
        m, d = self._draw()
        d.polygon([(x * self.k, y * self.k) for x, y in pts], fill=255)
        return self._arr(m)

    def line(self, pts, w=1, round_caps=True):
        m, d = self._draw()
        p = [(x * self.k, y * self.k) for x, y in pts]
        d.line(p, fill=255, width=round(w * self.k), joint='curve')
        if round_caps:
            r = w * self.k / 2
            for x, y in (p[0], p[-1]):
                d.ellipse([x - r, y - r, x + r, y + r], fill=255)
        return self._arr(m)

    def pixels(self, rows, x0, y0):
        """Пиксельная сетка в точках сетки 16. В крупном кадре точки - квадраты, полутонов нет."""
        levels = {'#': 1.0, '+': 0.55, '-': 0.25} if self.size == 16 else {'#': 1.0}
        m = np.zeros((16, 16), np.float32)
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch in levels and 0 <= x0 + i < 16 and 0 <= y0 + j < 16:
                    m[y0 + j, x0 + i] = levels[ch]
        rep = int(self.k)
        return np.kron(m, np.ones((rep, rep), np.float32))

    def fill(self, m, color):
        r, g, b, a = color
        k = np.clip(m, 0, 1) * a
        for i, v in enumerate((r, g, b)):
            self.c[..., i] = v * k + self.c[..., i] * (1 - k)
        self.a = k + self.a * (1 - k)

    def erase(self, m):
        k = 1 - np.clip(m, 0, 1)
        self.c *= k[..., None]
        self.a *= k

    def text(self, s, cx, baseline, cap, max_w):
        """Строка шрифтом LABEL_FONT: высота заглавных cap, по центру cx, не шире max_w."""
        k = self.k
        font = ImageFont.truetype(LABEL_FONT, 200)
        font.set_variation_by_axes(LABEL_AXES)
        font = ImageFont.truetype(LABEL_FONT, round(200 * cap * k / -font.getbbox('H', anchor='ls')[1]))
        font.set_variation_by_axes(LABEL_AXES)
        x0, y0, x1, y1 = font.getbbox(s, anchor='ls')
        im = Image.new('L', (x1 - x0, y1 - y0), 0)
        ImageDraw.Draw(im).text((-x0, -y0), s, font=font, fill=255, anchor='ls')
        w = min(im.width, round(max_w * k))
        im = im.resize((w, im.height), Image.LANCZOS)
        m = Image.new('L', (self.n, self.n), 0)
        m.paste(im, (round(cx * k - w / 2), round(baseline * k) + y0))
        return self._arr(m)

    def text_at(self, s, cx, bottom, cap, stroke=0):
        """Строка шрифтом LABEL_FONT: высота заглавных cap, низ букв на bottom, по центру cx.
        stroke - обводка в единицах сетки, из неё получается кайма вокруг букв."""
        k = self.k
        font = ImageFont.truetype(LABEL_FONT, 200)
        font.set_variation_by_axes(LABEL_AXES)
        font = ImageFont.truetype(LABEL_FONT, round(200 * cap * k / -font.getbbox('H', anchor='ls')[1]))
        font.set_variation_by_axes(LABEL_AXES)
        m, d = self._draw()
        d.text((cx * k, bottom * k), s, font=font, fill=255, anchor='ms', stroke_width=round(stroke * k), stroke_fill=255)
        return self._arr(m)

    def image(self):
        s, ss = self.size, self.ss
        c = self.c.reshape(s, ss, s, ss, 3).mean(axis=(1, 3))
        a = self.a.reshape(s, ss, s, ss).mean(axis=(1, 3))
        out = np.zeros((s, s, 4), np.float32)
        nz = a > 1e-6
        out[..., :3][nz] = c[nz] / a[nz][..., None]
        out[..., 3] = a
        return Image.fromarray(np.clip(out * 255 + 0.5, 0, 255).astype(np.uint8), 'RGBA')


WHITE = hexc('FFFFFF')


# ---------- части рисунков ----------
PHOTO = (1, 2, 15, 14)


def photo(c, t, outline=False):
    """Фото: горы и солнце в рамке. outline - горы и солнце контуром (сжатие с потерями)."""
    x0, y0, x1, y1 = PHOTO
    inner = c.rrect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, 1)
    if outline:
        near = c.line([(x0 + 0.5, y1 - 1.5), (6.0, 6.8), (10.4, y1 - 0.5)], 1.1)
        far = c.line([(8.2, 10.6), (11.1, 8.4), (15.5, 13.6)], 1.1)
        c.fill(np.clip(near + far, 0, 1) * inner, hexc(TEAL))
        c.fill(c.ring(11, 6, 1.6, 1.6, 1) * inner, hexc(SUN))
    else:
        far = c.poly([(7.3, y1), (11.1, 8.2), (15.5, 13.4), (x1, y1)])
        near = c.poly([(x0, y1), (x0, y1 - 1), (6.0, 6.6), (10.5, y1)])
        c.fill(np.clip(far + near, 0, 1) * inner, hexc(TEAL))
        c.fill(c.ellipse(11, 6, 1.35) * inner, hexc(SUN))
    c.fill(c.rrect_stroke(x0, y0, x1, y1, 2), hexc(t['stroke']))


def halo(rows):
    """Сетка каймы со сдвигом (-1, -1): точки rows, расширенные на 1 px во все стороны.
    Внутри прямоугольника подписи кайма сплошная, иначе фон просвечивает в середине W."""
    h, w = len(rows), len(rows[0])
    out = [['.'] * (w + 2) for _ in range(h + 2)]
    for j in range(h):
        for i in range(w):
            if rows[j][i] != '.':
                for dj in range(3):
                    for di in range(3):
                        out[j + dj][i + di] = '#'
    for j in range(1, h + 1):
        out[j][1:w + 1] = ['#'] * w
    return [''.join(r) for r in out]


def photo_label(c, text, color, narrow='', wide=''):
    """Подпись по низу иконки поверх рисунка, вокруг букв прозрачная кайма.
    narrow и wide - буквы, которые берутся из FONT_PHOTO_NARROW и FONT_PHOTO_WIDE."""
    if c.size == 16:
        rows = [''] * 5
        for k, ch in enumerate(text):
            glyph = FONT_PHOTO_NARROW[ch] if ch in narrow else FONT_PHOTO_WIDE[ch] if ch in wide else FONT_PHOTO[ch]
            for j in range(5):
                rows[j] += glyph[j] + ('.' if k < len(text) - 1 else '')
        x = (16 - len(rows[0]) + 1) // 2
        c.erase(c.pixels(halo(rows), x - 1, 10))
        c.fill(c.pixels(rows, x, 11), color)
    else:
        c.erase(c.text_at(text, 8, 16, 5, 1))
        c.fill(c.text_at(text, 8, 16, 5), color)


def palette(c):
    """Четыре цветных квадрата 3x3 по низу фото, вокруг прозрачная кайма."""
    c.erase(c.rect(0, 11, 16, 16))
    for i, col in enumerate(PALETTE):
        x = 1 + i * 4
        c.fill(c.rect(x, 12, x + 3, 15), hexc(col))


def frame_arrows(c, t, inward):
    """Двойная стрелка по диагонали рамки (resize_down). Наконечники в квадратах 3x3 у углов;
    при уменьшении вершина наконечника в противоположном углу того же квадрата."""
    c.fill(c.rrect_stroke(1, 1, 15, 15, 2), hexc(t['stroke']))
    col = hexc(BLUE)
    hw = 1 if c.size == 16 else 1.25            # в крупном кадре наконечник толщиной с древко
    tx0, tx1, ty0, ty1 = 8.5, 11.5, 4.5, 7.5   # квадрат верхнего наконечника
    bx0, bx1, by0, by1 = 4.5, 7.5, 8.5, 11.5   # нижнего
    if inward:
        c.fill(c.line([(tx0, ty1), (tx1, ty0)], 1.25), col)
        c.fill(c.line([(tx0, ty0), (tx0, ty1), (tx1, ty1)], hw), col)
        c.fill(c.line([(bx1, by0), (bx0, by1)], 1.25), col)
        c.fill(c.line([(bx0, by0), (bx1, by0), (bx1, by1)], hw), col)
    else:
        c.fill(c.line([(bx0, by1), (tx1, ty0)], 1.25), col)
        c.fill(c.line([(tx0, ty0), (tx1, ty0), (tx1, ty1)], hw), col)
        c.fill(c.line([(bx0, by0), (bx0, by1), (bx1, by1)], hw), col)


# Режимы размера: рамка заданного размера и картинка (x0, y0, x1, y1). Рамка одной высоты:
# «Вписать» 14 px, «Обрезать» 12, «Заполнить» 10. Картинка при вписывании целиком внутри
# с зазором 1 px, при заполнении шире рамки, при обрезке от неё остаётся середина
SIZE_FRAMES = {'resize': (1, 1, 15, 15), 'fill': (3, 1, 13, 15), 'trim': (2, 1, 14, 15)}
SIZE_IMAGE_FIT = (3, 4, 13, 12)
SIZE_IMAGE = (0, 2, 16, 14)
SIZE_IMAGE_CROP = (4, 3, 12, 13)
DASH = (2, 1)             # пунктир рамки: черта, пропуск
DASH_GAP = 0.35           # пропуск пунктира не пустой, а полупрозрачный


def landscape(c, t, rect, clip):
    """Горы и солнце как у фото сжатия, в долях прямоугольника rect, на светлом небе."""
    x0, y0, x1, y1 = rect
    w, h = x1 - x0, y1 - y0
    pt = lambda u, v: (x0 + u * w, y0 + v * h)
    c.fill(clip, hexc(t['sky']))
    far = c.poly([pt(0.45, 1), pt(0.721, 0.517), pt(1.036, 0.95), pt(1, 1)])
    near = c.poly([pt(0, 1), pt(0, 0.917), pt(0.357, 0.383), pt(0.679, 1)])
    c.fill(np.clip(far + near, 0, 1) * clip, hexc(TEAL))
    cx, cy = pt(0.714, 0.333)
    c.fill(c.ellipse(cx, cy, max(1.1, 0.11 * h)) * clip, hexc(SUN))


def dashed_frame(c, f):
    """Рамка пунктиром: скругления углов сплошные, прямые участки - черта и пропуск DASH,
    пропуск закрашен на DASH_GAP."""
    x0, y0, x1, y1 = f
    on, off = DASH
    solid = c.rrect_stroke(x0, y0, x1, y1, 2)
    corners = np.clip(sum(c.rect(x, y, x + 2, y + 2) for x in (x0, x1 - 2) for y in (y0, y1 - 2)), 0, 1)
    dash = 0
    for i, x in enumerate(range(x0 + 2, x1 - 2)):
        if i % (on + off) < on:
            dash = dash + c.rect(x, y0, x + 1, y0 + 1) + c.rect(x, y1 - 1, x + 1, y1)
    for i, y in enumerate(range(y0 + 2, y1 - 2)):
        if i % (on + off) < on:
            dash = dash + c.rect(x0, y, x0 + 1, y + 1) + c.rect(x1 - 1, y, x1, y + 1)
    sides = solid * (1 - corners)
    return np.clip(solid * corners + sides * (DASH_GAP + (1 - DASH_GAP) * np.clip(dash, 0, 1)), 0, 1)


def size_mode(c, t, mode):
    f = SIZE_FRAMES[mode]
    if mode == 'resize':
        landscape(c, t, SIZE_IMAGE_FIT, c.rrect(*SIZE_IMAGE_FIT, 1.5))
    elif mode == 'fill':
        landscape(c, t, SIZE_IMAGE, c.rrect(*SIZE_IMAGE, 1.5))
        # вокруг рамки прозрачная кайма: видно, где кончается размер
        c.erase(c.rrect_stroke(f[0] - 1, 0, f[2] + 1, 16, 3, 3))
    else:
        landscape(c, t, SIZE_IMAGE, c.rrect(*SIZE_IMAGE_CROP, 1.5))
    c.fill(dashed_frame(c, f), hexc(t['stroke']))


def page(c, t, band=None, body=None):
    """Лист с загнутым углом: контур в 1 px, как рамки фото, углы скруглены тем же радиусом 2.
    Лист высотой 15, с отступом 1 сверху. Контур - разность внешней и внутренней фигуры,
    у каждой срезан угол по линии x - y. Загиб 3 px, его нижний край прячется под полосой.
    band - цвет полосы под подпись формата, body - заливка листа."""
    r2 = 2 ** 0.5   # внутренний срез угла сдвинут на 1 по нормали
    outer = c.rrect(2, 1, 14, 16, 2) * (1 - c.poly([(10, 0), (17, 0), (17, 7)]))
    inner = c.rrect(3, 2, 13, 15, 1) * (1 - c.poly([(10 - r2, 0), (17, 0), (17, 7 + r2)]))
    fold = (c.rect(10, 1, 11, 4) + c.rect(10, 4, 14, 5)) * outer
    if body:
        c.fill(inner, hexc(body))
    c.fill(np.clip(outer - inner + fold, 0, 1), hexc(t['stroke']))
    if band:
        c.fill(c.rrect(0, 4, 16, 13, 1.5), hexc(band))


# ---------- рисунки Fluent UI System Icons (MIT, Assets/Fluent) ----------
FLUENT_DIR = os.path.join(HERE, 'Fluent')
FLUENT_SRC = {16: 16, 20: 20, 24: 24, 32: 16, 48: 24, 64: 16, 256: 24}   # кадр: рисунок какого размера


def svg_contours(d):
    """Контуры пути SVG из абсолютных M L H V C Z, кривые разбиты на отрезки."""
    tok = re.findall(r'[MLHVCZ]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?', d)
    out, pts, cmd, i = [], [], None, 0
    num = lambda n: [float(v) for v in tok[i:i + n]]
    while i < len(tok):
        if tok[i] in 'MLHVCZ':
            cmd = tok[i]
            i += 1
            if cmd == 'Z':
                out.append(pts)
                pts = []
            continue
        x, y = pts[-1] if pts else (0, 0)
        if cmd == 'M':
            if pts:
                out.append(pts)
            pts = [tuple(num(2))]
            i += 2
            cmd = 'L'
        elif cmd == 'L':
            pts.append(tuple(num(2)))
            i += 2
        elif cmd == 'H':
            pts.append((num(1)[0], y))
            i += 1
        elif cmd == 'V':
            pts.append((x, num(1)[0]))
            i += 1
        elif cmd == 'C':
            x1, y1, x2, y2, x3, y3 = num(6)
            i += 6
            for k in range(1, 13):
                u = k / 12
                a, b, e, f = (1 - u) ** 3, 3 * u * (1 - u) ** 2, 3 * u * u * (1 - u), u ** 3
                pts.append((a * x + b * x1 + e * x2 + f * x3, a * y + b * y1 + e * y2 + f * y3))
    if pts:
        out.append(pts)
    return [p for p in out if len(p) > 2]


def fluent(c, name):
    """Маска рисунка Fluent (правило nonzero: контуры складываются со знаком площади) и маска
    круга значка - контура с наибольшей площадью, чей центр в левой нижней четверти."""
    s = FLUENT_SRC[c.size]
    svg = open(os.path.join(FLUENT_DIR, f'ic_fluent_{name}_{s}_regular.svg'), encoding='utf-8').read()
    total, disc, best = 0, 0, 0
    for pts in svg_contours(re.search(r' d="([^"]+)"', svg).group(1)):
        pts = [(x * 16 / s, y * 16 / s) for x, y in pts]
        area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1])) / 2
        m = c.poly(pts)
        total = total + np.sign(area) * m
        xs, ys = zip(*pts)
        if min(xs) + max(xs) < 16 and min(ys) + max(ys) > 16 and abs(area) > best:
            disc, best = m, abs(area)
    return np.clip(np.abs(total), 0, 1), disc


# square-menu из Lucide. Его линия 2 из 24 в 16 и 20 px ложится между пикселями и мылится,
# поэтому рисунок разложен вручную по пикселям каждого источника, кадры берутся из них, как у
# Fluent (FLUENT_SRC). Источник: рамка (от, до, радиус, толщина), строки (от, до, верх каждой), толщина строки
SQUARE_MENU = {
    16: ((2, 15, 2, 1), (5, 12, (5, 8, 11)), 1),
    20: ((2, 19, 2, 1), (6, 15, (6, 10, 14)), 1),
    24: ((2, 22, 3, 2), (6, 18, (7, 11, 15)), 2),   # как в Lucide: строки со скруглёнными концами
}


def square_menu(c):
    s = FLUENT_SRC[c.size]
    k = 16 / s
    (b0, b1, r, w), (x0, x1, ys), h = SQUARE_MENU[s]
    m = c.rrect_stroke(b0 * k, b0 * k, b1 * k, b1 * k, r * k, w * k)
    for y in ys:
        m = m + (c.rect(x0 * k, y * k, x1 * k, (y + h) * k) if h == 1 else
                 c.rrect(x0 * k, y * k, x1 * k, (y + h) * k, h * k / 2))
    return np.clip(m, 0, 1)


# Иконки exe: имя файла в Assets/Icons и маска рисунка. Цвет один на обе темы проводника
EXE_COLOR = '808B96'
EXE_ICONS = {
    'Launcher': lambda c: fluent(c, 'flash')[0],   # Launcher.exe: отдаёт задание Moth
    'Menu': square_menu,                           # Menu.exe: окна выбора действия и размеров
}


def label_rows(text):
    rows = [''] * 7
    for k, ch in enumerate(text):
        for j in range(7):
            rows[j] += FONT[ch][j] + ('.' if k < len(text) - 1 else '')
    if len(rows[0]) > LABEL_MAX:
        raise ValueError(f'подпись {text!r} шире {LABEL_MAX} px, нужна короче')
    return rows


def format_icon(c, t, text, color):
    page(c, t, color)
    rows = label_rows(text)
    if c.size == 16:
        c.erase(c.pixels(rows, (16 - len(rows[0]) + 1) // 2, 5))
    else:
        c.erase(c.text(text, 8, 12, 7, LABEL_VEC_MAX))


def convert(c, t, color):
    """Лист формата, подпись - многоточие: точки 2x2 через 2 px, низ на строку выше низа букв.
    Точки пиксельные во всех кадрах."""
    page(c, t, color)
    rows = ['..'.join(['##'] * 3)] * 2
    c.erase(c.pixels(rows, (16 - len(rows[0]) + 1) // 2, 9))


# ---------- набор ----------
def icons(theme):
    t = THEMES[theme]
    band = (lambda col: tint(col, DARK_TINT)) if theme == 'dark' else (lambda col: col)
    out = {
        'lossless': lambda c: photo(c, t),
        'lossless_exif': lambda c: (photo(c, t), photo_label(c, 'EXIF', hexc(t['stroke']), 'EX')),
        'lossy': lambda c: photo(c, t, outline=True),
        'web': lambda c: (photo(c, t), photo_label(c, 'WEB', hexc(BLUE), 'E')),
        'cq': lambda c: (photo(c, t), palette(c)),
        'resize': lambda c: size_mode(c, t, 'resize'),
        'resize_down': lambda c: frame_arrows(c, t, True),
        'fill': lambda c: size_mode(c, t, 'fill'),
        'trim': lambda c: size_mode(c, t, 'trim'),
        'convert': lambda c: convert(c, t, band(BLUE)),
    }
    for mode in ('resize', 'fill', 'trim'):
        for key, (text, color, narrow, wide) in RESIZE_FILTERS.items():
            col = hexc(tint(color, LABEL_DARK_TINT) if theme == 'dark' else color)
            out[mode + '_' + key] = (lambda base, text, col, narrow, wide:
                                     lambda c: (base(c), photo_label(c, text, col, narrow, wide)))(out[mode], text, col, narrow, wide)
    for key, (text, color) in FORMATS.items():
        out['format_' + key] = (lambda text, color: lambda c: format_icon(c, t, text, band(color)))(text, color)
    return out


def render(fn, size):
    c = Canvas(size)
    fn(c)
    return c.image()


def ico_frame(im):
    """Кадр ICO: мелкий - 32-битный DIB с маской, крупный - PNG."""
    s = im.width
    if s >= PNG_FROM:
        buf = io.BytesIO()
        im.save(buf, 'PNG', optimize=True)
        return buf.getvalue()
    a = np.asarray(im)[::-1]
    bgra = a[:, :, [2, 1, 0, 3]].tobytes()
    stride = (s + 31) // 32 * 4
    mask = b''.join(np.packbits(row[:, 3] == 0).tobytes().ljust(stride, b'\0') for row in a)
    return struct.pack('<IiiHHIIiiII', 40, s, s * 2, 1, 32, 0, len(bgra) + len(mask), 0, 0, 0, 0) + bgra + mask


def save_ico(fn, path):
    data = [ico_frame(render(fn, s)) for s in SIZES]
    head = struct.pack('<HHH', 0, 1, len(data))
    off = 6 + 16 * len(data)
    for s, d in zip(SIZES, data):
        head += struct.pack('<BBBBHHII', s % 256, s % 256, 0, 0, 1, 32, len(d), off)
        off += len(d)
    with open(path, 'wb') as f:
        f.write(head + b''.join(data))


def sheet(path):
    """Все иконки 16 px: строка светлой темы и строка тёмной, плюс увеличение 4x."""
    sets = {th: {n: render(fn, 16) for n, fn in icons(th).items()} for th in THEMES}
    names = list(sets['light'])
    z, cols = 4, 12
    cell = 16 * z + 8
    rows = (len(names) + cols - 1) // cols
    im = Image.new('RGBA', (cols * cell * 2 + 8, rows * cell + 8), (30, 34, 44, 255))
    for i, n in enumerate(names):
        x, y = 8 + (i % cols) * cell * 2, 8 + (i // cols) * cell
        for k, (th, bg) in enumerate((('light', (242, 242, 242, 255)), ('dark', (43, 43, 43, 255)))):
            tile = Image.new('RGBA', (16, 16), bg)
            tile.alpha_composite(sets[th][n])
            im.paste(tile.resize((16 * z, 16 * z), Image.NEAREST), (x + k * (16 * z + 2), y))
    im.save(path)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(HERE, '..', 'Themes'), help='папка с Light и Dark')
    ap.add_argument('--sheet', help='PNG со всеми иконками для просмотра')
    args = ap.parse_args()
    for theme in THEMES:
        # Папки и файлы с большой буквы: Themes/Dark/ResizeDown.ico
        folder = os.path.join(args.out, theme.capitalize())
        os.makedirs(folder, exist_ok=True)
        for name, fn in icons(theme).items():
            save_ico(fn, os.path.join(folder, ''.join(p.capitalize() for p in name.split('_')) + '.ico'))
    for exe, mask in EXE_ICONS.items():
        save_ico(lambda c, mask=mask: c.fill(mask(c), hexc(EXE_COLOR)), os.path.join(HERE, 'Icons', exe + '.ico'))
    if args.sheet:
        sheet(args.sheet)
    print('ok')
