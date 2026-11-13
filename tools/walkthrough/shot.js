const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({viewport:{width:1280,height:900}});
  const errs = []; await p.route('**/katex.min.js', r => r.fulfill({path:process.env.KATEX_JS || require.resolve('katex/dist/katex.min.js'), contentType:'application/javascript'})); await p.route('**fonts.g*/**', r => r.abort()); p.on('pageerror', e => errs.push(String(e))); p.on('console', m => { if (m.type()==='error' && !m.text().includes('ERR_FAILED')) errs.push(m.text()); });
  const html = require('fs').readFileSync(process.argv[2], 'utf8');
  await p.setContent('<!doctype html><html><head><meta charset=utf8><meta name=viewport content="width=device-width,initial-scale=1"></head><body>' + html + '</body></html>', {waitUntil:'networkidle'});
  const steps = (process.argv[4]||'1').split(',');
  for (const s of steps) {
    const [d, st] = s.split(':');
    if (st) await p.evaluate(([d,st]) => { document.querySelector(`.dbtn[data-d="${d}"]`).click(); document.querySelector(`.sbtn[data-s="${st}"]`).click(); }, [d, st]);
    await p.evaluate(() => document.querySelector('#walk').scrollIntoView());
    await p.screenshot({path: process.argv[3].replace('.png', `_${d}_${st||0}.png`), fullPage: false});
  }
  if (process.argv[5]) await p.screenshot({path: process.argv[5], fullPage: true});
  console.log('errors', JSON.stringify(errs));
  await b.close();
})();
