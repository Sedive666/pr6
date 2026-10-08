"""Собирает снимки одного экрана в одну картинку для отчёта.

Из четырёх снимков (360, 768, 1280, 1920) получается один рисунок: панели
стоят сеткой два на два, под каждой подписана ширина окна. Именно в таком
виде снимки вставляются в отчёт — одна иллюстрация на экран.

    py tools/compose.py
"""

import os
from PIL import Image, ImageDraw, ImageFont

SRC = os.path.join("отчёт", "screenshots")
DST = os.path.join("отчёт", "рисунки")

WIDTHS = [360, 768, 1280, 1920]
TITLES = {
    "1-vhod": "Рисунок 1 - Вход в систему",
    "2-glavnaya-admin": "Рисунок 2 - Главная (администратор)",
    "3-spisok-krossovok": "Рисунок 3 - Список кроссовок",
    "4-kartochka-krossovok": "Рисунок 4 - Карточка кроссовок",
    "5-forma-izmeneniya": "Рисунок 5 - Форма изменения кроссовок",
    "6-spisok-pokupatelei": "Рисунок 6 - Список покупателей",
}

CELL_W, CELL_H = 980, 760     # место под одну панель
GAP, PAD, CAPTION = 40, 40, 56
BG = (255, 255, 255)
BORDER = (190, 190, 190)
TEXT = (30, 30, 30)


def font(size):
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def fit(image, box_w, box_h):
    k = min(box_w / image.width, box_h / image.height, 1.0)
    return image.resize((max(1, int(image.width * k)), max(1, int(image.height * k))), Image.LANCZOS)


def compose(name):
    panels = []
    for w in WIDTHS:
        path = os.path.join(SRC, f"{name}-{w}.png")
        if not os.path.exists(path):
            return None
        panels.append((w, fit(Image.open(path).convert("RGB"), CELL_W, CELL_H)))

    sheet_w = PAD * 2 + CELL_W * 2 + GAP
    sheet_h = PAD * 2 + (CELL_H + CAPTION) * 2 + GAP
    sheet = Image.new("RGB", (sheet_w, sheet_h), BG)
    draw = ImageDraw.Draw(sheet)
    label = font(30)

    for i, (w, panel) in enumerate(panels):
        col, row = i % 2, i // 2
        cell_x = PAD + col * (CELL_W + GAP)
        cell_y = PAD + row * (CELL_H + CAPTION + GAP)
        x = cell_x + (CELL_W - panel.width) // 2
        y = cell_y + (CELL_H - panel.height) // 2
        sheet.paste(panel, (x, y))
        draw.rectangle([x - 1, y - 1, x + panel.width, y + panel.height], outline=BORDER)
        text = f"{w} px"
        tw = draw.textlength(text, font=label)
        draw.text((cell_x + (CELL_W - tw) / 2, cell_y + CELL_H + 8), text, fill=TEXT, font=label)

    os.makedirs(DST, exist_ok=True)
    out = os.path.join(DST, f"{TITLES[name]}.png")
    sheet.save(out)
    return out


def main():
    for name in TITLES:
        out = compose(name)
        print(out if out else f"{name}: не хватает снимков")


if __name__ == "__main__":
    main()
