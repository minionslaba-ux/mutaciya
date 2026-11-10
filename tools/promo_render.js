// Рисует 365 картинок 1080x1080 для ежедневной рассылки по promo/daily/posts.json.
// Мутантов рисует сама игра (тестовый хук window.__mut). Запуск: node tools/promo_render.js [с_дня] [по_день]
const {chromium}=require('playwright');const http=require('http'),fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');const out=path.join(root,'promo','daily');
const posts=JSON.parse(fs.readFileSync(path.join(out,'posts.json'),'utf8')).posts;
const from=+process.argv[2]||1,to=+process.argv[3]||posts.length;
const srv=http.createServer((q,r)=>{let f=path.join(root,decodeURIComponent(q.url.split('?')[0]));if(f.endsWith('/'))f+='index.html';
  fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);r.end();return}r.writeHead(200,{'content-type':{'.html':'text/html; charset=utf-8','.js':'text/javascript','.woff2':'font/woff2'}[path.extname(f)]||'application/octet-stream'});r.end(d)})}).listen(8771);
const PAL=[['#5c4a1d','#1d1608'],['#5a5a16','#191a05'],['#432060','#12071c'],['#1d5c3c','#05170d'],['#62330f','#1c0d03'],['#5e1c20','#1a0507'],['#1f5a44','#061811'],['#24324f','#070b16']];
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;');
(async()=>{const b=await chromium.launch();const g=await b.newPage();await g.route(/^https?:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
  await g.goto('http://127.0.0.1:8771/#test');await g.waitForTimeout(800);
  const forms={},anoms={};for(let i=0;i<20;i++)forms[i]=await g.evaluate(i=>__mut.drawForm(i,620),i);
  for(const k of ['rot','parasite','mutagen','acid','mirror','magnet','brood','worm','doll'])anoms[k]=await g.evaluate(k=>__mut.drawAnom(k,620),k);
  const font=n=>`@font-face{font-family:'${n}';src:url(http://127.0.0.1:8771/fonts/${n}-cyrillic-400-normal.woff2)}@font-face{font-family:'${n}';src:url(http://127.0.0.1:8771/fonts/${n}-latin-400-normal.woff2);unicode-range:U+0000-00FF}`;
  const fonts=['rubik-wet-paint','rubik-distressed','rubik-glitch','ibm-plex-sans','ibm-plex-mono'].map(font).join('');
  const p=await b.newPage({viewport:{width:1080,height:1080}});await p.route(/^https?:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
  await p.goto('http://127.0.0.1:8771/README.md').catch(()=>{});await p.goto('http://127.0.0.1:8771/nope.html'); // same origin as the fonts
  for(const post of posts.filter(x=>x.day>=from&&x.day<=to)){const a=post.art,[c1,c2]=PAL[a.palette];
    const img=a.kind==='anom'?anoms[a.anom]:forms[a.form];const subFs=a.sub.length>110?30:a.sub.length>70?34:38;
    const deco={laser:`<div style="position:absolute;left:0;right:0;top:46%;height:6px;background:#ff3a2a;box-shadow:0 0 30px 8px rgba(255,40,30,.7)"></div>`,
      cryo:`<div style="position:absolute;left:0;right:0;bottom:0;height:34%;background:linear-gradient(rgba(210,240,255,.55),rgba(150,200,240,.35));border-top:3px solid rgba(255,255,255,.7)"></div>`,
      uv:`<div style="position:absolute;inset:0;background:radial-gradient(circle at 50% 50%,rgba(0,0,0,0) 22%,rgba(10,0,20,.85) 48%)"></div>`,
      centri:`<div style="position:absolute;inset:0;background:repeating-linear-gradient(90deg,rgba(255,255,255,.07) 0 6px,transparent 6px 60px)"></div>`,
      disinf:`<div style="position:absolute;left:0;right:0;top:30%;height:30%;background:linear-gradient(rgba(130,255,160,0),rgba(150,255,170,.45),rgba(130,255,160,0))"></div>`}[a.trial]||'';
    const top=`<div class="m" style="position:absolute;top:34px;left:44px;font-size:22px">Смена лаборанта №${a.day}</div><div class="logo" style="position:absolute;top:24px;right:44px;font-size:52px">МУТАЦИЯ</div>`;
    const foot=`<div class="ch"><span>ЗАДАНИЕ ДНЯ</span>${esc(a.challenge)}</div><div class="m" style="position:absolute;bottom:26px;left:0;right:0;text-align:center;font-size:20px;color:#9a8a78">mutaciya.com</div>`;
    let body;
    if(a.kind==='intro')body=`<div style="text-align:center;padding-top:110px"><div class="logo" style="font-size:170px;line-height:1">МУТАЦИЯ</div><img src="${img}" style="width:440px;margin-top:6px"><div class="d" style="font-size:44px;margin:0 80px">${esc(a.sub)}</div></div>`;
    else if(a.layout===0)body=`<div style="text-align:center;padding-top:110px"><div class="d h" style="font-size:${a.headline.length>16?64:84}px">${esc(a.headline)}</div><img src="${img}" style="width:470px;margin-top:4px"><div class="s" style="font-size:${subFs}px;margin:0 90px">${esc(a.sub)}</div></div>`;
    else if(a.layout===1)body=`<img src="${img}" style="position:absolute;left:-40px;top:200px;width:600px"><div style="position:absolute;left:540px;right:50px;top:230px"><div class="d h" style="font-size:${a.headline.length>14?54:70}px;line-height:1.05">${esc(a.headline)}</div><div class="s" style="font-size:${subFs}px;margin-top:24px">${esc(a.sub)}</div></div>`;
    else if(a.layout===2)body=`<div style="position:absolute;left:70px;right:70px;top:140px;bottom:300px;background:linear-gradient(#211813,#140e0b);border:2px solid #3a2820;padding:50px;transform:rotate(-1.2deg)"><div class="m" style="font-size:22px;color:#ff6a5e">ЖУРНАЛ ЛАБОРАНТА</div><div class="d h" style="font-size:64px;margin-top:16px">${esc(a.headline)}</div><div style="font-family:'ibm-plex-mono';font-size:${subFs+6}px;line-height:1.5;margin-top:22px;color:#e9dcc2">${esc(a.sub)}</div></div><img src="${img}" style="position:absolute;right:20px;bottom:150px;width:330px;transform:rotate(8deg)">`;
    else body=`<img src="${img}" style="position:absolute;left:50%;top:44%;width:900px;transform:translate(-50%,-50%)"><div style="position:absolute;left:0;right:0;bottom:150px;padding:60px 60px 20px;background:linear-gradient(transparent,rgba(0,0,0,.88) 45%);text-align:center"><div class="d h" style="font-size:${a.headline.length>16?62:80}px">${esc(a.headline)}</div><div class="s" style="font-size:${subFs}px;margin-top:10px">${esc(a.sub)}</div></div>`;
    const html=`<style>${fonts}*{margin:0;box-sizing:border-box}body{width:1080px;height:1080px;overflow:hidden;position:relative;color:#efe4cc;font-family:'ibm-plex-sans';
      background:radial-gradient(110% 90% at 50% 45%,${c1} 0%,${c2} 55%,#020101 100%)}
      .logo{font-family:'rubik-wet-paint';color:#c8141a;text-shadow:0 0 26px rgba(200,10,10,.45)}.d{font-family:'rubik-distressed'}.h{color:#f4e6cc;text-shadow:0 3px 0 #000,0 0 30px rgba(0,0,0,.6)}
      .s{line-height:1.3;color:#e8dcc4;text-shadow:0 2px 8px #000}.m{font-family:'ibm-plex-mono';letter-spacing:.12em;text-transform:uppercase;color:#ff6a5e}
      .ch{position:absolute;left:60px;right:60px;bottom:70px;background:rgba(0,0,0,.6);border:2px solid #b3181e;padding:16px 20px;font-size:28px;text-align:center;font-family:'ibm-plex-sans'}
      .ch span{display:block;font-family:'ibm-plex-mono';font-size:18px;letter-spacing:.2em;color:#ff5a4e;margin-bottom:4px}
      .grain{position:absolute;inset:0;background-image:url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='180' height='180'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='.85' numOctaves='2'/><feColorMatrix values='0 0 0 0 1  0 0 0 0 1  0 0 0 0 1  0 0 0 1 -.15'/></filter><rect width='100%25' height='100%25' filter='url(%23n)'/></svg>");opacity:.08}
      .vig{position:absolute;inset:0;background:radial-gradient(circle at 50% 50%,transparent 55%,rgba(0,0,0,.6))}</style>
      ${deco}${body}<div class="vig"></div>${top}${foot}<div class="grain"></div>`;
    await p.setContent(html);await p.evaluate(async()=>{await Promise.all(['rubik-wet-paint','rubik-distressed','ibm-plex-sans','ibm-plex-mono'].map(f=>document.fonts.load(`40px "${f}"`,'МУТАЦИЯ abc')));await document.fonts.ready});await p.waitForTimeout(60);
    await p.screenshot({path:path.join(out,String(post.day).padStart(3,'0')+'.jpg'),type:'jpeg',quality:80});
    if(post.day%50===0)console.log('готово',post.day)}
  await b.close();srv.close();console.log('картинки',from,'–',to)})();
