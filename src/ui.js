import { SUBS } from './data.js';
import { T } from './gfx.js';

const $ = (id) => document.getElementById(id);
const el = (tag, cls, html) => { const e = document.createElement(tag); if (cls) e.className = cls; if (html != null) e.innerHTML = html; return e; };
let auto = null;
export const setAuto = (f) => { auto = f; };
export const isAuto = () => !!auto;

const tone = (v) => (v >= 70 ? 'ok' : v >= 40 ? 'warn' : 'bad');

export function updateHud(s) {
  const bar = (label, v, max, cls) => `<div class="row"><span>${label}</span><div class="bar"><i class="${cls}" style="width:${Math.max(0, Math.min(100, (v / max) * 100))}%"></i></div><b>${Math.round(v)}</b></div>`;
  $('hud').innerHTML =
    bar('Power', s.power, 100, tone(s.power)) +
    bar('Budget', s.budget, 120, tone((s.budget / 120) * 100)) +
    `<div class="row2"><span>Day</span><b>${s.days} / 300</b><span>Science</span><b>${s.science}</b></div>`;
}

export function updateSubs(s) {
  const rows = SUBS.map((x) => {
    const shield = x.id === 'shield';
    const v = shield ? s.knownShield : s.h[x.id];
    const note = shield
      ? `<small>${s.shieldCheckedDay < 0 ? 'never inspected' : 'inspected day ' + s.shieldCheckedDay} · cannot be seen from inside</small>`
      : '';
    return `<div class="sub ${tone(v)}"><div class="nm">${x.name}${shield ? ' <em>(last known)</em>' : ''}<b>${Math.round(v)}%</b></div><div class="bar"><i class="${tone(v)}" style="width:${v}%"></i></div>${note}</div>`;
  }).join('');
  $('subs').innerHTML = '<h3>Ship systems</h3>' + rows;
}

let cueTimer = 0;
export function cue(text) {
  const c = $('cue');
  c.textContent = '♪ ' + text;
  c.classList.add('show');
  clearTimeout(cueTimer);
  cueTimer = setTimeout(() => c.classList.remove('show'), 5200 / T.speed);
}

export function toast(text, kind = '') {
  const t = el('div', 'toast ' + kind, text);
  $('toasts').appendChild(t);
  setTimeout(() => t.classList.add('out'), 5200 / T.speed);
  setTimeout(() => t.remove(), 5800 / T.speed);
}

export function flash(color = 'rgba(255,60,40,.35)') {
  const f = $('flash');
  f.style.background = color;
  f.style.transition = 'none'; f.style.opacity = '1';
  requestAnimationFrame(() => { f.style.transition = 'opacity .7s'; f.style.opacity = '0'; });
}

export function mini(html) {
  const m = $('mini');
  if (html == null) { m.classList.remove('show'); return; }
  if (m._last !== html) { m.innerHTML = html; m._last = html; }
  m.classList.add('show');
}

const hide = (d) => { d.className = 'panel'; d.innerHTML = ''; };

export function say(title, text, btn = 'Continue') {
  if (auto) { auto('say', { title, text }); return Promise.resolve(); }
  return new Promise((res) => {
    const d = $('dialog');
    d.className = 'panel show';
    d.innerHTML = `<h2>${title}</h2><p>${text}</p>`;
    const b = el('button', 'btn main', btn);
    b.onclick = () => { hide(d); res(); };
    d.appendChild(b);
    b.focus();
  });
}

export function choose(id, title, text, options) {
  if (auto) {
    const pick = auto('choose', { id, title, options });
    return Promise.resolve(pick);
  }
  return new Promise((res) => {
    const d = $('dialog');
    d.className = 'panel show';
    d.innerHTML = `<h2>${title}</h2><p>${text}</p>`;
    const list = el('div', 'opts');
    options.forEach((o) => {
      const b = el('button', 'opt' + (o.disabled ? ' off' : ''),
        `<b>${o.dot ? `<i class="dot" style="background:${o.dot}"></i>` : ''}${o.label}</b>${o.sub ? `<span>${o.sub}</span>` : ''}`);
      b.disabled = !!o.disabled;
      b.onclick = () => { hide(d); res(o.id); };
      list.appendChild(b);
    });
    d.appendChild(list);
  });
}

export function powerPanel(units, systems, seconds, intro) {
  if (auto) return Promise.resolve({ chosen: auto('power', { units, systems }), timedOut: false });
  return new Promise((res) => {
    const d = $('dialog');
    d.className = 'panel show alert';
    d.innerHTML = `<h2>Sudden power drop!</h2><p>${intro}</p>`;
    const sel = new Set();
    const info = el('div', 'tally');
    const timer = el('div', 'bar big'); const ti = el('i', 'bad'); timer.appendChild(ti);
    const list = el('div', 'opts power');
    const upd = () => {
      const used = [...sel].reduce((a, id) => a + systems.find((x) => x.id === id).cost, 0);
      info.innerHTML = `Using <b class="${used > units ? 'bad' : 'ok'}">${used}</b> of <b>${units}</b> power units`;
    };
    systems.forEach((x) => {
      const b = el('button', 'opt', `<b>${x.name}</b><span>${x.cost} units</span>`);
      b.onclick = () => { if (sel.has(x.id)) { sel.delete(x.id); b.classList.remove('on'); } else { sel.add(x.id); b.classList.add('on'); } upd(); };
      list.appendChild(b);
    });
    const go = el('button', 'btn main', 'Confirm');
    let left = seconds, last = performance.now(), done = false;
    const finish = (timedOut) => { if (done) return; done = true; hide(d); res({ chosen: [...sel], timedOut }); };
    go.onclick = () => finish(false);
    const tick = (now) => {
      if (done) return;
      left -= ((now - last) / 1000) * T.speed; last = now;
      ti.style.width = Math.max(0, (left / seconds) * 100) + '%';
      if (left <= 0) finish(true); else requestAnimationFrame(tick);
    };
    d.append(info, timer, list, go);
    upd();
    requestAnimationFrame(tick);
  });
}

export function crewSelect(crew) {
  if (auto) return Promise.resolve(auto('crew', {}));
  return new Promise((res) => {
    const o = $('overlay');
    o.className = 'show';
    o.innerHTML = '<div class="card"><h1>Choose your crew</h1><p>Pick 3 of 4 specialists. Each one changes how later events play out.</p></div>';
    const card = o.firstChild;
    const sel = new Set();
    const list = el('div', 'opts crew');
    const go = el('button', 'btn main', 'Launch (pick 3)');
    go.disabled = true;
    crew.forEach((c) => {
      const b = el('button', 'opt', `<b>${c.name}</b><span>${c.desc}</span>`);
      b.onclick = () => {
        if (sel.has(c.id)) { sel.delete(c.id); b.classList.remove('on'); }
        else if (sel.size < 3) { sel.add(c.id); b.classList.add('on'); }
        go.disabled = sel.size !== 3;
        go.textContent = sel.size === 3 ? 'Launch' : `Launch (pick ${3 - sel.size} more)`;
      };
      list.appendChild(b);
    });
    go.onclick = () => { o.className = ''; o.innerHTML = ''; res([...sel]); };
    card.append(list, go);
  });
}

export function title(html, btn) {
  if (auto) return Promise.resolve();
  return new Promise((res) => {
    const o = $('overlay');
    o.className = 'show';
    o.innerHTML = `<div class="card">${html}</div>`;
    const b = el('button', 'btn main', btn);
    b.onclick = () => { o.className = ''; o.innerHTML = ''; res(); };
    o.firstChild.appendChild(b);
  });
}

export function report(html, btn, onBtn) {
  const o = $('overlay');
  o.className = 'show report';
  o.innerHTML = `<div class="card wide">${html}</div>`;
  const b = el('button', 'btn main', btn);
  b.onclick = onBtn;
  o.firstChild.appendChild(b);
}

export function hideAll() { hide($('dialog')); mini(null); }
