# Комментарии к посту на Пикабу: python3 tools/pikabu_comments.py [story_id] → список «автор (рейтинг): текст», ответы с отступом.
import json, re, sys, html, urllib.request, urllib.parse
SID = sys.argv[1] if len(sys.argv) > 1 else '14532467'
UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36'
def get(start=0):
    data = urllib.parse.urlencode({'action': 'get_story_comments', 'story_id': SID, 'start_comment_id': start}).encode()
    req = urllib.request.Request('https://pikabu.ru/ajax/comments_actions.php', data=data, headers={'User-Agent': UA, 'X-Requested-With': 'XMLHttpRequest', 'Referer': f'https://pikabu.ru/story/_{SID}'})
    return json.load(urllib.request.urlopen(req, timeout=20))['data']
d = get(); out = []
for c in d['comments']:
    h = c['html']
    name = (re.search(r'data-name="([^"]*)"', h) or re.search(r'comment__user[^>]*>\s*<[^>]*>([^<]+)', h))
    rating = re.search(r'comment__rating-count[^>]*>\s*([-\d]+)', h)
    body = re.search(r'class="comment__content"[^>]*>(.*?)</div>', h, re.S)
    t = html.unescape(re.sub(r'<br\s*/?>', ' ', body.group(1) if body else ''))
    t = re.sub(r'\s+', ' ', re.sub('<[^>]+>', ' ', t)).strip()
    date = re.search(r'datetime="([^"]+)"', h)
    out.append({'id': c['id'], 'parent': c['parent_id'], 'name': name.group(1).strip() if name else '?', 'rating': rating.group(1) if rating else '', 'date': date.group(1) if date else '', 'text': t})
ids = {c['id']: c for c in out}
def depth(c):
    n = 0
    while c['parent'] and c['parent'] in ids: c = ids[c['parent']]; n += 1
    return n
print(f"Комментариев: {d.get('total')}")
for c in out: print('  ' * depth(c) + f"[{c['id']}] {c['name']} ({c['rating']}) {c['date'][11:16]}: {c['text']}")
