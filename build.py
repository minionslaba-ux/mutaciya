#!/usr/bin/env python3
"""Собирает index.html для GitHub Pages из src/game.html.

src/game.html — исходник страницы (та же версия публикуется на claude.ai).
В index.html все внешние ресурсы заменяются локальными, чтобы игра
открывалась без Cloudflare (cdnjs) и Google Fonts:
  - Matter.js  -> vendor/matter-0.19.0.min.js
  - шрифты     -> fonts/*.woff2 (через встроенный @font-face)

Запуск: python3 build.py
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent
src = (ROOT / "src" / "game.html").read_text(encoding="utf-8")

CDN_MATTER = "https://cdnjs.cloudflare.com/ajax/libs/matter-js/0.19.0/matter.min.js"
assert CDN_MATTER in src, "ссылка на Matter.js в исходнике изменилась"
src = src.replace(CDN_MATTER, "vendor/matter-0.19.0.min.js")

# убрать Google Fonts
src, n = re.subn(r'<link rel="preconnect" href="https://fonts\.googleapis\.com">\n?', "", src)
src, m = re.subn(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com/[^"]*">\n?', "", src)
assert m == 1, "ссылка на Google Fonts в исходнике изменилась"

CYR = "U+0301,U+0400-045F,U+0490-0491,U+04B0-04B1,U+2116"
LAT = "U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD"
faces = []
for family, slug, weights in [
    ("Russo One", "russo-one", [400]),
    ("IBM Plex Sans", "ibm-plex-sans", [400, 600]),
    ("IBM Plex Mono", "ibm-plex-mono", [400, 600]),
]:
    for w in weights:
        for subset, rng in (("cyrillic", CYR), ("latin", LAT)):
            faces.append(
                f'@font-face{{font-family:"{family}";font-style:normal;font-weight:{w};font-display:swap;'
                f'src:url(fonts/{slug}-{subset}-{w}-normal.woff2) format("woff2");unicode-range:{rng}}}'
            )
font_css = "<style>\n" + "\n".join(faces) + "\n</style>\n"

assert "http" not in re.sub(r'https?://(brm\.io|github\.com)[^\s"<]*', "", src.split("<script>")[0]), \
    "в разметке остались внешние ссылки"

head = """<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover,user-scalable=no">
<meta name="theme-color" content="#13110c">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="description" content="Мутация — хоррор-головоломка со слиянием существ в банке с формалином.">
"""
cut = src.index("</style>") + len("</style>")
out = head + font_css + src[:cut] + "\n</head>\n<body>\n" + src[cut:].lstrip("\n") + "</body>\n</html>\n"
(ROOT / "index.html").write_text(out, encoding="utf-8")
print("index.html собран:", len(out), "байт")
