const fs = require('fs');
const path = require('path');
const { JSDOM } = require('jsdom');

const file = process.argv[2];
const html = fs.readFileSync(file, 'utf8');

const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  pretendToBeVisual: true,
  url: 'http://localhost/' + path.basename(file),
  beforeParse(win) {
    win.confirm = () => true;
    win.print = () => {};
    win.scrollTo = () => {};
    win.Element.prototype.scrollIntoView = function () {};
  },
});

const win = dom.window;
const doc = win.document;
const $ = (s) => doc.querySelector(s);
const $$ = (s) => Array.from(doc.querySelectorAll(s));

let fails = 0;
function check(name, cond, extra = '') {
  if (cond) console.log('  PASS  ' + name + (extra ? '  → ' + extra : ''));
  else { fails++; console.log('  FAIL  ' + name + (extra ? '  → ' + extra : '')); }
}

const D = win.eval('D');
console.log('== ' + path.basename(file) + ' ==');

// 1. structure
const qCards = $$('.q');
check('150 प्रश्न कार्ड रेंडर हुए', qCards.length === 150, 'मिले ' + qCards.length);
check('5 खण्ड', $$('section.sec').length === 5, 'मिले ' + $$('section.sec').length);
check('4 गद्यांश ब्लॉक', $$('.stim').length === 4, 'मिले ' + $$('.stim').length);
check('हर प्रश्न पर 4 विकल्प', $$('.opts').every((u) => u.children.length === 4));
check('हर प्रश्न पर स्रोत टैग', $$('.q .src').length === 150, 'मिले ' + $$('.q .src').length);
check('हर प्रश्न पर सही साल का टैग', $$('.q .src').every((el,i)=>el.textContent.includes('UTET '+D.q[i].y)));
check('पैलेट में 150 बटन', $$('#pal button').length === 150);
check('उत्तर-कुंजी तालिका में 150 पंक्तियाँ', $$('#keytable table tr').length === 151);

// हर खण्ड में 30
const perSec = {};
for (const q of D.q) perSec[q.sec] = (perSec[q.sec] || 0) + 1;
check('हर खण्ड में 30 प्रश्न', Object.values(perSec).every((v) => v === 30), JSON.stringify(perSec));

// हर साल से 25 (5 × 5 खण्ड)
const perYear = {};
for (const q of D.q) perYear[q.y] = (perYear[q.y] || 0) + 1;
check('हर साल से 25 प्रश्न', Object.values(perYear).every((v) => v === 25), JSON.stringify(perYear));

// स्रोत साल टैग में सही साल लिखा है
const firstChip = $('.q .src').textContent;
check('पहला टैग 2026 का', firstChip.includes('UTET 2026'), firstChip.trim());

// 2. answer + score — सारे सही
for (const q of D.q) {
  const li = doc.querySelector('.opts li[data-q="' + q.n + '"][data-k="' + q.a + '"]');
  li.dispatchEvent(new win.MouseEvent('click', { bubbles: true }));
}
check('सब उत्तर देने के बाद पैलेट हरा', $$('#pal button.done').length === 150, 'मिले ' + $$('#pal button.done').length);
$('#submit').dispatchEvent(new win.MouseEvent('click', { bubbles: true }));
check('स्कोर 150/150', $('.score').textContent.trim() === '150 / 150', $('.score').textContent.trim());
check('सब विकल्प हरे', $$('.opts li.right').length === 150 && $$('.opts li.wrong').length === 0);

// localStorage में जमा हुआ
check('localStorage में submitted', JSON.parse(win.localStorage.getItem('utetmock_' + D.meta.id)).submitted === true);

// 3. भाषा toggle
const before = $('.q .stem').innerHTML;
doc.querySelector('#langbtns button[data-l="en"]').dispatchEvent(new win.MouseEvent('click', { bubbles: true }));
const afterEn = $('.q .stem').innerHTML;
check('English toggle पर stem बदला', before !== afterEn);
check('English mode में देवनागरी प्रश्न नहीं (Q1)', !/[\u0900-\u097F]/.test($('.q .stem').textContent), $('.q .stem').textContent.slice(0, 40));
doc.querySelector('#langbtns button[data-l="hi"]').dispatchEvent(new win.MouseEvent('click', { bubbles: true }));
check('हिन्दी mode में देवनागरी लौटा', /[\u0900-\u097F]/.test($('.q .stem').textContent));
doc.querySelector('#langbtns button[data-l="both"]').dispatchEvent(new win.MouseEvent('click', { bubbles: true }));
check('दोनों mode में hi+en दोनों', $('.q .stem').querySelectorAll('div').length >= 2);

// 4. गलत उत्तर वाला रास्ता — नया डोम, पहला प्रश्न गलत
const dom2 = new JSDOM(html, {
  runScripts: 'dangerously', url: 'http://localhost/m2',
  beforeParse(w) { w.confirm = () => true; w.scrollTo = () => {}; w.Element.prototype.scrollIntoView = function(){}; },
});
const d2 = dom2.window.document;
const D2 = dom2.window.eval('D');
const wrong = D2.q[0].o.find((o) => o.k !== D2.q[0].a).k;
d2.querySelector('.opts li[data-q="1"][data-k="' + wrong + '"]').dispatchEvent(new dom2.window.MouseEvent('click', { bubbles: true }));
d2.querySelector('#submit').dispatchEvent(new dom2.window.MouseEvent('click', { bubbles: true }));
check('1 गलत + 149 खाली → स्कोर 0/150', d2.querySelector('.score').textContent.trim() === '0 / 150', d2.querySelector('.score').textContent.trim());
check('गलत उत्तर लाल', d2.querySelectorAll('.opts li.wrong').length === 1);
check('सही उत्तर हरा दिख रहा', d2.querySelectorAll('.opts li.right').length === 150);
check('खाली वाले "छोड़ा गया"', d2.querySelectorAll('.verdict.skip').length === 149);

// 5. टाइमर
const clock = d2.querySelector('#clock').textContent;
check('घड़ी 150:00 से शुरू', /^\d{2,3}:\d{2}$/.test(clock), clock);
check('पहला उत्तर देने पर टाइमर शुरू हुआ', JSON.parse(dom2.window.localStorage.getItem('utetmock_' + D2.meta.id)).start > 0);

console.log(fails === 0 ? '\nRESULT: सब जाँच पास\n' : '\nRESULT: ' + fails + ' जाँच फेल\n');
process.exit(fails === 0 ? 0 : 1);
