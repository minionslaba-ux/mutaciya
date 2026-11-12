# Сборка «Мутации» для Пикабу Игр (напрямую через SDK Пикабу, как у «Ночного тарифа»): pikabu/index.html на нашем сайте —
# https://mutaciya.com/pikabu/ (шрифты и физика берутся из общих папок сайта через <base href="/">, поисковикам — noindex).
# Берёт собранный index.html и: ставит window.MUT_PLATFORM='pikabu' (SDK Пикабу, без ссылок наружу, Робокассы, рекламы
# сайта, напоминаний, установки и общей таблицы рекордов); убирает манифест, сервис-воркер, canonical, метки соцсетей и
# строку внизу меню со ссылками на страницы сайта и данными владельца (замечание модерации Пикабу к «Ночному тарифу»).
# Запуск: python3 tools/build_pikabu.py (вызывается из build.py)
import pathlib, re
ROOT = pathlib.Path(__file__).resolve().parent.parent
d = (ROOT / 'index.html').read_text(encoding='utf-8')
for pat in [r'<link rel="manifest"[^>]*>\n?', r'<link rel="canonical"[^>]*>\n?', r'<meta property="og:[^>]*>\n?', r'<meta name="twitter:[^>]*>\n?',
            r'<link rel="apple-touch-icon"[^>]*>\n?', r'<meta name="apple-mobile-web-app[^>]*>\n?', r'<meta name="mobile-web-app-capable"[^>]*>\n?']:
    d = re.sub(pat, '', d)
d, n = re.subn(r'<p class="site-legal">.*?</p>\n?', '', d, flags=re.S); assert n == 1, 'нет строки с документами'
d, n = re.subn(r"<script>\nif\('serviceWorker' in navigator.*?</script>\n", '', d, flags=re.S); assert n == 1, 'нет регистрации service worker'
k = d.index('<meta charset="utf-8">') + len('<meta charset="utf-8">\n')
d = d[:k] + '<base href="/">\n<meta name="robots" content="noindex">\n<script>window.MUT_PLATFORM="pikabu";</script>\n' + d[k:]
assert 'manifest' not in d and 'serviceWorker.register' not in d and 'site-legal">' not in d
(ROOT / 'pikabu').mkdir(exist_ok=True)
(ROOT / 'pikabu' / 'index.html').write_text(d, encoding='utf-8')
print('pikabu: pikabu/index.html', len(d), 'байт (https://mutaciya.com/pikabu/)')
