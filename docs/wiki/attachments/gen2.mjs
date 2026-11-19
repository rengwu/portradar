import fs from 'node:fs';
const src = fs.readFileSync('gen1.mjs','utf8');
// reuse base css + icons from round 1
const base = src.match(/const base = (`[\s\S]*?`);/)[1];
const copySvg = src.match(/const copy = (`.*?`);/)[1], openSvg = src.match(/const open = (`.*?`);/)[1];
const B = eval(base), copy = eval(copySvg), open = eval(openSvg);
const folder = `<svg class="ic" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3"><path d="M2 4.5A1.5 1.5 0 0 1 3.5 3H6l1.5 1.5h5A1.5 1.5 0 0 1 14 6v5.5a1.5 1.5 0 0 1-1.5 1.5h-9A1.5 1.5 0 0 1 2 11.5z"/></svg>`;
const stop = `<svg class="ic" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3"><rect x="3.5" y="3.5" width="9" height="9" rx="1.5"/></svg>`;
const glyph = `<svg class="ic" viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.4"><rect x="2" y="3" width="12" height="10" rx="2"/><path d="M5 7l2 1.5L5 10M8.5 10h3"/></svg>`;
const bar = `<div class="bar"><span class="me">${glyph}</span><span>Tue 17 Nov 10:42</span></div>`;
const data = [
 {p:4178,proj:'quinecms',kind:'Vite',sub:'tools/admin-gallery'},
 {p:4179,proj:'quinecms',kind:'Python',sub:'http.server'},
 {p:4321,proj:'quinesystems-site',kind:'Node',sub:'quinecms dev'},
 {p:4322,proj:'quinecms-demo-site',kind:'Node',sub:'quinecms dev'},
 {p:4410,proj:'quinecms-landing-site',kind:'Vite',sub:'vite preview'},
];
const foot = `<div class="sep"></div><div class="row dim">Show all listeners<span class="sp"></span><span class="small">14 hidden</span></div><div class="row">Settings…<span class="sp"></span><span class="dim small">⌘,</span></div><div class="row">Quit PortRadar<span class="sp"></span><span class="dim small">⌘Q</span></div>`;
const hov = `<span style="display:flex;gap:9px;color:#fff">${copy}${open}</span>`;
const groups = {}; data.forEach(d=>(groups[d.proj]??=[]).push(d));
const grouped = (row) => B + bar + `<div class="menu">` + Object.entries(groups).map(([g,rows],gi)=>`<div class="hdr">${g}</div>`+rows.map((d,i)=>row(d, gi==0&&i==0)).join('')).join('') + foot + `</div>`;
const port = d => `<span class="port" style="width:44px">:${d.p}</span>`;
const G1 = grouped((d,h)=>`<div class="row ${h?'hl':''}">${port(d)}<span>${d.kind}</span><span class="sp"></span>${h?hov:''}</div>`);
const G2 = grouped((d,h)=>`<div class="row ${h?'hl':''}">${port(d)}<span>${d.kind}</span><span class="dim" style="margin-left:6px">${d.sub}</span><span class="sp"></span>${h?hov:''}</div>`);
const G3 = grouped((d,h)=>`<div class="row ${h?'hl':''}">${port(d)}<span>${d.sub}</span><span class="sp"></span>${h?hov:`<span class="dim small">${d.kind}</span>`}</div>`);
const flat = B + bar + `<div class="menu">` + data.map((d,i)=>`<div class="row ${i==0?'hl':''}">${port(d)}<span>${d.proj}</span><span class="sp"></span>${i==0?hov:`<span class="dim small">${d.kind}</span>`}</div>`).join('') + foot + `</div>`;
const one = (right, extra='') => B + `<div class="menu" style="margin:16px auto">` + `<div class="hdr">quinecms</div><div class="row hl">${port(data[0])}<span>Vite</span><span class="sp"></span>${right}</div><div class="row">${port(data[1])}<span>Python</span><span class="sp"></span><span class="dim small"></span></div>${extra}</div>`;
const ctx = one(hov, `<div style="position:relative"><div class="menu" style="position:absolute;left:160px;top:-22px;width:190px"><div class="row">Open in Browser</div><div class="row">Copy URL</div><div class="sep"></div><div class="row">Reveal in Finder</div><div class="row">Stop Process</div></div></div><div style="height:130px"></div>`);
const four = one(`<span style="display:flex;gap:9px;color:#fff">${folder}${stop}${copy}${open}</span>`);
const opt = one(`<span style="display:flex;gap:9px;color:#fff">${folder}${stop}</span>`, `<p class="dim small" style="padding:8px 9px">While ⌥ is held, copy/open swap to reveal/stop.</p>`);
const q = { projectName:'PortRadar', title:'PortRadar round 2: row detail', number:9, questions:[
 { id:'recap', context:`**Settled from round 1**
- Two modes: **Grouped by project** and **Simple** (flat list, like A)
- Clicking a row opens it in the browser. Copy and open icons appear on hover.
- Menubar icon dims when nothing is running
- Hidden by default: system daemons, GUI apps, agent CLIs, ephemeral ports with no known framework
- Address: \`http://localhost:PORT\`
- Extras: stop process, reveal folder, launch at login

Below: rows in grouped mode use A's style, with no dots and no separator characters. The first row is shown hovered.` },
 { id:'grouped-row', prompt:'In grouped mode, what goes on each row under the project header?', recommendation:'2: the kind is still readable at a glance. The detail separates the ports when one project runs two Vite servers.', options:[
   {id:'kind',label:'1 · Port + kind only',preview:{html:G1,height:340}},
   {id:'kind-detail',label:'2 · Port + kind + dim detail',preview:{html:G2,height:340}},
   {id:'detail-kind-right',label:'3 · Port + detail, kind dim on the right (exactly A’s shape)',preview:{html:G3,height:340}} ]},
 { id:'flat', prompt:'Simple mode: this is A with hover icons. Is it right?', options:[{id:'ok',label:'Looks right',preview:{html:flat,height:300}}] },
 { id:'secondary', prompt:'Where do Reveal in Finder and Stop Process live?', recommendation:'Right-click menu: it keeps the row clean, and Stop stays out of the way of accidental clicks.', options:[
   {id:'context',label:'Right-click menu',preview:{html:ctx,height:230}},
   {id:'four-icons',label:'All four icons on hover',preview:{html:four,height:150}},
   {id:'option',label:'Hold ⌥ to swap the icons',preview:{html:opt,height:170}} ]},
 { id:'stop-confirm', prompt:'Stopping a process:', recommendation:'SIGTERM immediately. If it is still alive after 3 s, the row offers Force Quit.', options:['SIGTERM immediately, offer Force Quit if it survives','Confirm first, every time'] },
 { id:'mode-toggle', prompt:'Where is the Grouped / Simple switch?', recommendation:'Settings: keeps the dropdown free of controls.', options:['Settings only','Small toggle in the dropdown'] }
]};
fs.writeFileSync(process.argv[2], JSON.stringify(q,null,1));
