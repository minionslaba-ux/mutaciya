# «Мутация» — правила для Claude

- Игра — один файл `src/game.html`; `python3 build.py` собирает сайт (`index.html`) и сборку для Пикабу (`pikabu/index.html`) — обе всегда из одного исходника. Перед коммитом: `python3 build.py` и `node tools/soak.js 15`.
- Миссии, уровни, задания, волны, боссы — только по скиллу .claude/skills/raznoobraznye-missii (каталог docs/missii-katalog.md, таблица новых миссий владельцу до кода, проверка check_missions.py).
