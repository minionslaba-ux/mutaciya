// Длительная проверка: случайная игра во всех режимах с принудительными событиями.
// Запуск: npm i playwright (один раз), затем node tools/soak.js [секунд_на_режим]
// long random-play soak test: every mode, forced events, invariants checked each second
const {chromium,devices}=require('playwright');const http=require('http'),fs=require('fs'),path=require('path');
const root=require('path').resolve(__dirname,'..');
const srv=http.createServer((q,r)=>{let f=path.join(root,decodeURIComponent(q.url.split('?')[0]));if(f.endsWith('/'))f+='index.html';
  fs.readFile(f,(e,d)=>{if(e){r.writeHead(404);r.end();return}r.writeHead(200,{'content-type':{'.html':'text/html; charset=utf-8','.js':'text/javascript','.woff2':'font/woff2'}[path.extname(f)]||'application/octet-stream'});r.end(d)})}).listen(8769);
const SCEN=[['classic','#playBtn'],['fall','#fallBtn'],['daily','#dailyBtn'],['calm','#playBtn'],['trial0',null],['trial2',null],['trial4',null]];
const DUR=+process.argv[2]||45;
(async()=>{const b=await chromium.launch();const c=await b.newContext({...devices['iPhone 13']});const p=await c.newPage();
  const errs=[];p.on('pageerror',e=>errs.push(e.message));p.on('console',m=>{if(m.type()==='error'&&!/ERR_FAILED|vibrate/.test(m.text()))errs.push(m.text())});
  await p.route(/^https?:\/\/(?!127\.0\.0\.1)/,r=>r.abort());
  await p.goto('http://127.0.0.1:8769/#test');await p.evaluate(()=>{localStorage.setItem('mut.stats',JSON.stringify({games:12}));localStorage.setItem('mut.tut','true');localStorage.setItem('mut.trials',JSON.stringify({laser:1,disinf:1,uv:1,centri:1,cryo:1}))});
  const problems=[];
  for(const [name,btn] of SCEN){
    await p.reload();await p.waitForTimeout(500);
    await p.evaluate(n=>{const o=JSON.parse(localStorage.getItem('mut.opts')||'{}');o.calm=n==='calm';o.scare=true;localStorage.setItem('mut.opts',JSON.stringify(o))},name);await p.reload();await p.waitForTimeout(500);
    if(btn)await p.tap(btn);else{await p.tap('#trialBtn');await p.waitForTimeout(200);await p.locator('.trial button').nth(+name.slice(5)).tap()}
    await p.waitForTimeout(400);const box=await (await p.$('#cv')).boundingBox();
    let lastT=-1,stuck=0,games=0,maxScream=0;const t0=Date.now();
    while(Date.now()-t0<DUR*1000){
      const r=Math.random();
      if(r<.55){await p.mouse.move(box.x+box.width*Math.random(),box.y+60);await p.mouse.down();await p.mouse.move(box.x+box.width*Math.random(),box.y+70,{steps:2});await p.mouse.up()}
      else if(r<.6){await p.evaluate(()=>{for(const id of ['abShake','abSwap','abDown','abFire'])if(Math.random()<.4){const e=document.getElementById(id);if(e&&!e.hidden&&!e.disabled)e.click()}})}
      else if(r<.64){await p.evaluate(()=>__mut.hzSet({nextLeak:0,nextKnock:0,nextHand:0,nextInspect:0,nextLight:0,nextGaze:0}))}
      else if(r<.67){await p.evaluate(()=>{const b=document.getElementById('leakPay');if(!b.closest('.leakpop').hidden&&!b.disabled)b.click();else{const l=document.getElementById('leakLater');if(!l.closest('.leakpop').hidden)l.click()}})}
      else if(r<.69){await p.tap('#regBtn');await p.waitForTimeout(150);await p.tap('#regClose')}
      else if(r<.71){await p.tap('#menuBtn');await p.waitForTimeout(200);await p.tap('#resumeBtn').catch(()=>{})}
      else if(r<.73){await p.evaluate(()=>__mut.spawn(Math.floor(Math.random()*12),60+Math.random()*280,120))}
      else if(r<.76){await p.evaluate(()=>__mut.gameOver())}
      else if(r<.77){await p.evaluate(()=>{localStorage.removeItem('mut.fake');__mut.fake()});await p.waitForTimeout(2600)}
      else if(r<.79&&name.startsWith('trial')){await p.evaluate(()=>{__mut.setScore(900);__mut.hzSet({t:200000});__mut.spawn(7,200,500)})}
      await p.waitForTimeout(250);
      const s=await p.evaluate(()=>({over:!document.getElementById('over').hidden,overFlag:__mut.fall().mode&&true,menu:!document.getElementById('menu').hidden,
        hzT:__mut.hz().t,scream:!document.getElementById('scream').hidden,leakPop:!document.getElementById('leakPop').hidden,leak:__mut.leak().leak,
        sheets:[...document.querySelectorAll('.scrim')].filter(x=>!x.hidden).length,bodies:__mut.bodies().length}));
      // «Продолжить смену» (только на сайте): случайно продолжаем или заканчиваем
      if(await p.evaluate(()=>!document.getElementById('contSheet').hidden)){await p.evaluate(()=>document.getElementById(Math.random()<.5?'contAd':'contEnd').click());await p.waitForTimeout(300);lastT=-1;continue}
      if(s.over){games++;await p.tap('#again').catch(()=>{});await p.waitForTimeout(300);lastT=-1;continue}
      if(s.leakPop&&!s.leak)problems.push(name+': окно утечки без утечки');
      if(s.scream){maxScream++;if(maxScream>12)problems.push(name+': скример завис')}else maxScream=0;
      if(!s.menu&&s.sheets===0&&!s.scream){if(s.hzT===lastT){stuck++;if(stuck>12){problems.push(name+': игра не идёт (время стоит)');stuck=0}}else stuck=0;lastT=s.hzT}
    }
    console.log(name.padEnd(8),'партий завершено:',games);
  }
  console.log('ошибок JS:',errs.length,errs.slice(0,5));console.log('проблем:',problems.length,[...new Set(problems)]);
  await b.close();srv.close()})();
