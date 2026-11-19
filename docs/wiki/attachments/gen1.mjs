import fs from 'node:fs';
const out = process.argv[2];
const base = `<style>*{box-sizing:border-box;margin:0}body{padding:18px 24px;background:linear-gradient(160deg,#3a4152,#1d2029);font:13px -apple-system,system-ui,sans-serif;color:#e8e9ed;min-height:100vh}
.bar{display:flex;justify-content:flex-end;gap:14px;align-items:center;height:22px;margin:-18px -24px 8px;padding:0 16px;background:rgba(30,32,38,.55);font-size:12.5px;color:#eee}
.bar .me{padding:1px 7px;border-radius:5px;background:rgba(255,255,255,.18);display:flex;gap:4px;align-items:center}
.menu{margin-left:auto;width:330px;background:rgba(40,42,48,.86);backdrop-filter:blur(20px);border:1px solid rgba(255,255,255,.13);border-radius:11px;padding:5px;box-shadow:0 12px 40px rgba(0,0,0,.45)}
.row{display:flex;align-items:center;gap:8px;padding:5px 9px;border-radius:6px;min-height:24px}
.row.hl{background:#2f6fe0}.row.hl .dim,.row.hl .port{color:#fff}
.dim{color:#9a9ea8}.port{font:12px ui-monospace,SFMono-Regular,Menlo,monospace;color:#c9ccd3}
.sep{height:1px;background:rgba(255,255,255,.1);margin:5px 9px}
.hdr{font-size:11px;font-weight:600;color:#8d919b;padding:6px 9px 2px}
.sp{flex:1}.ic{width:15px;height:15px;opacity:.8}.small{font-size:11px}
.badge{font-size:10px;font-weight:600;padding:1px 5px;border-radius:4px;letter-spacing:.2px}
.vite{background:#6d4cd9;color:#fff}.node{background:#3c873a;color:#fff}.py{background:#3572a5;color:#fff}.go{background:#00add8;color:#063}.next{background:#eee;color:#111}
.dot{width:7px;height:7px;border-radius:50%}
</style>`;
const glyph = `<svg class="ic" viewBox="0 0 16 16" fill="none" stroke="#fff" stroke-width="1.4"><rect x="2" y="3" width="12" height="10" rx="2"/><path d="M5 7l2 1.5L5 10M8.5 10h3"/></svg>`;
const bar = (label) => `<div class="bar"><span class="me">${label}</span><span>Tue 17 Nov 10:42</span></div>`;
const copy = `<svg class="ic" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3"><rect x="5" y="5" width="8" height="9" rx="1.5"/><path d="M3 11V3.5A1.5 1.5 0 0 1 4.5 2H10"/></svg>`;
const open = `<svg class="ic" viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="1.3"><path d="M9 2h5v5M14 2 7 9M12 10v3.5a.5.5 0 0 1-.5.5h-9a.5.5 0 0 1-.5-.5v-9a.5.5 0 0 1 .5-.5H6"/></svg>`;
const data = [
 {p:4178,proj:'quinecms',kind:'Vite',b:'vite',sub:'tools/admin-gallery'},
 {p:4179,proj:'quinecms',kind:'Python',b:'py',sub:'http.server'},
 {p:4321,proj:'quinesystems-site',kind:'Node',b:'node',sub:'quinecms dev',lan:true},
 {p:4322,proj:'quinecms-demo-site',kind:'Node',b:'node',sub:'quinecms dev'},
 {p:4410,proj:'quinecms-landing-site',kind:'Vite',b:'vite',sub:'vite preview'},
];
const foot = `<div class="sep"></div><div class="row dim">Show all listeners <span class="sp"></span><span class="small">14 hidden</span></div><div class="row">Settings…<span class="sp"></span><span class="dim small">⌘,</span></div><div class="row">Quit PortRadar<span class="sp"></span><span class="dim small">⌘Q</span></div>`;

// A: native NSMenu-ish, port first
const A = base + bar(glyph+' 5') + `<div class="menu">` + data.map((d,i)=>`<div class="row ${i==0?'hl':''}"><span class="port" style="width:44px">:${d.p}</span><span>${d.proj}</span><span class="sp"></span><span class="dim small">${d.kind}</span></div>`).join('') + foot + `</div>`;
// B: grouped by project
const groups = {}; data.forEach(d=>(groups[d.proj]??=[]).push(d));
const B = base + bar(glyph+' 5') + `<div class="menu">` + Object.entries(groups).map(([g,rows],gi)=>`<div class="hdr">${g}</div>`+rows.map((d,i)=>`<div class="row ${gi==0&&i==0?'hl':''}"><span class="dot" style="background:${{vite:'#8b6cf0',node:'#4caf50',py:'#4a8fd0'}[d.b]}"></span><span>${d.kind} <span class="dim">· ${d.sub}</span></span><span class="sp"></span><span class="port">:${d.p}</span></div>`).join('')).join('') + foot + `</div>`;
// C: two-line rows with badge and hover actions
const C = base + bar(glyph+' 5') + `<div class="menu" style="width:350px">` + data.map((d,i)=>`<div class="row ${i==0?'hl':''}" style="padding:6px 9px"><span class="badge ${d.b}" style="width:46px;text-align:center">${d.kind}</span><div style="line-height:1.25"><div>${d.proj}</div><div class="dim small">localhost:${d.p} · ${d.sub}</div></div><span class="sp"></span>${i==0?`<span style="display:flex;gap:8px;color:#fff">${copy}${open}</span>`:''}</div>`).join('') + foot + `</div>`;
// D: ultra-minimal, just ports, project on right
const D = base + bar(glyph) + `<div class="menu" style="width:260px">` + data.map((d,i)=>`<div class="row ${i==0?'hl':''}"><span class="port" style="font-size:13px">${d.p}</span><span class="sp"></span><span class="dim">${d.proj.replace('quinecms-','qc-')}</span></div>`).join('') + foot + `</div>`;

const H = 330;
const rowPreview = (inner) => base + `<div class="menu" style="margin:20px auto">${inner}</div>`;
const r0 = data[0];
const actA = rowPreview(`<div class="row hl"><span class="port" style="width:44px">:4178</span><span>quinecms</span><span class="sp"></span><span style="display:flex;gap:8px">${copy}${open}</span></div><div class="row"><span class="port" style="width:44px">:4179</span><span>quinecms</span><span class="sp"></span><span class="dim small">Python</span></div><p class="dim small" style="padding:10px">Icons appear on hover. Row click = open in browser.</p>`);
const actB = rowPreview(`<div class="row hl"><span class="port" style="width:44px">:4178</span><span>quinecms</span><span class="sp"></span><span class="small">Copied ✓</span></div><div class="row"><span class="port" style="width:44px">:4179</span><span>quinecms</span><span class="sp"></span><span class="dim small">Python</span></div><p class="dim small" style="padding:10px">Click = open in browser. ⌥-click = copy URL (row text changes to "Copy http://localhost:4178" while ⌥ is held).</p>`);
const actC = rowPreview(`<div class="row hl"><span class="port" style="width:44px">:4178</span><span>quinecms</span><span class="sp"></span><span class="small">›</span></div><div style="position:relative"><div class="menu" style="position:absolute;left:250px;top:-30px;width:200px"><div class="row">Open in Browser</div><div class="row">Copy URL</div><div class="row">Copy Port</div><div class="sep"></div><div class="row">Reveal Folder</div><div class="row">Stop Process…</div></div></div><p class="dim small" style="padding:10px;width:240px">Each row opens a submenu of actions.</p>`);

const q = {
 projectName: 'PortRadar', title: 'PortRadar: what is running on which port',
 questions: [
 { id:'feasibility', context:`**Feasibility: works, no root, no sandbox.** A menubar app like Klip and Yacht (Swift + AppKit, macOS 13+, ad-hoc signed).

| Need | Source |
|---|---|
| Listening TCP ports + PID | \`libproc\` (\`proc_pidfdinfo\`), no subprocess; \`lsof\` as a fallback |
| Project folder | the process's cwd, walking up to the nearest \`.git\` / \`package.json\` / \`go.mod\` / \`pyproject.toml\` / \`Cargo.toml\` |
| Process kind | argv (\`vite.js\`, \`next dev\`, \`-m http.server\`, \`uvicorn\`, \`go-build…/exe\`) and then \`package.json\` deps |
| Refresh | polling every 2–3 s while the menu is closed, plus on open (about 50 ms) |

**Limits:** processes owned by other users (root, Docker's VM) show the port but not the cwd. Docker containers appear as \`com.docker.backend\`, but container names can come from \`docker ps\` later.

**What your machine shows right now:** 19 listeners, but only **5 are dev servers**. The rest are 7× codex, 5× claude (agent CLIs on random high ports), Discord, and rapportd. So filtering out noise matters more than adding features. The previews below use your actual 5.` },
 { id:'layout', prompt:'Which dropdown layout?', recommendation:'A: the closest to Klip/Yacht minimalism. Kind is plain text, and rows are scannable by port.', options:[
   {id:'flat',label:'A · Flat list, port first',preview:{html:A,height:H}},
   {id:'grouped',label:'B · Grouped by project',preview:{html:B,height:H+60}},
   {id:'badges',label:'C · Two-line rows with kind badges',preview:{html:C,height:H+40}},
   {id:'bare',label:'D · Bare: port + folder only',preview:{html:D,height:H}} ]},
 { id:'actions', prompt:'How do open / copy work on a row?', recommendation:'A: both are one click, and you can find them without learning a modifier.', options:[
   {id:'hover-icons',label:'Row click opens; hover icons for copy/open',preview:{html:actA,height:200}},
   {id:'option-click',label:'Click opens; ⌥-click copies (pure native menu)',preview:{html:actB,height:200}},
   {id:'submenu',label:'Submenu of actions per row',preview:{html:actC,height:260}} ]},
 { id:'menubar', prompt:'Menubar icon?', options:['Icon only','Icon + count of dev ports','Count only (hidden when 0)','Icon, dimmed when nothing is running'], recommendation:'Icon + count.' },
 { id:'noise', prompt:'What should be hidden by default (still reachable via "Show all")?', selection:'multiple', recommendation:'All of the first four.', options:['macOS system daemons (rapportd, ControlCenter…)','GUI apps (Discord, Spotify, Figma helpers…)','Agent CLIs on random ports (codex, claude)','Ephemeral high ports (> 49152) with no known framework','Loopback-only listeners (only show 0.0.0.0 / LAN)'] },
 { id:'address', prompt:'Which address gets copied/opened?', recommendation:'localhost; offer the LAN IP for *:port binds as a secondary action.', options:['http://localhost:PORT','http://127.0.0.1:PORT','LAN IP when bound to all interfaces, else localhost'] },
 { id:'extras', prompt:'Which extras, if any? (minimal means saying no)', selection:'multiple', recommendation:'Stop process + Reveal folder + Launch at login. Skip the rest for v1.', options:['Stop process (SIGTERM, then offer SIGKILL)','Reveal project folder in Finder','Open project in editor (VS Code / Cursor / Zed)','Show uptime','Notify when a new port opens','Global hotkey to open the menu','Rename / pin a port manually','Docker container names','Launch at login'] },
 { id:'notes', prompt:'Anything else about the look and feel? (e.g. reference screenshots, things you dislike in whattheport / ports-app / leftopen)' }
 ]};
fs.writeFileSync(out, JSON.stringify(q,null,1));
