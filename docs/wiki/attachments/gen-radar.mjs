import fs from 'fs';
const C=412;
const pt=(r,a)=>{const t=(a-90)*Math.PI/180;return [(C+r*Math.cos(t)).toFixed(1),(C+r*Math.sin(t)).toFixed(1)]};
function radar({bg, bezel, R, screenR, ringR=screenR, ticks, full}){
  // Trail: nested wedges ending at the lead line, each adding a little opacity, so the ramp has no seams.
  let trail='';const lead=60,span=80,N=24, rr=full?900:screenR;
  for(let i=0;i<N;i++){const a0=lead-span*(1-i/N);const [x0,y0]=pt(rr,a0),[x1,y1]=pt(rr,lead);
    trail+=`<path d="M${C} ${C} L${x0} ${y0} A${rr} ${rr} 0 0 1 ${x1} ${y1}Z" fill="#4DF07C" opacity="0.045"/>`;}
  const [lx,ly]=pt(rr,lead);
  const blip=(r,a,s,o)=>{const [x,y]=pt(r,a);return `<circle cx="${x}" cy="${y}" r="${s*2.4}" fill="#4DF07C" opacity="${o*.55}" filter="url(#bl)"/><circle cx="${x}" cy="${y}" r="${s}" fill="#C8FFD6" opacity="${o}"/>`};
  let tk='';if(ticks)for(let a=0;a<360;a+=15){const big=a%45==0;const [x0,y0]=pt(screenR+14,a),[x1,y1]=pt(screenR+(big?40:28),a);tk+=`<line x1="${x0}" y1="${y0}" x2="${x1}" y2="${y1}" stroke="#2A3038" stroke-opacity=".55" stroke-width="${big?7:4}" stroke-linecap="round"/>`;}
  const bez = bezel? `<circle cx="${C}" cy="${C}" r="${R}" fill="url(#bez)" filter="url(#sh)"/><circle cx="${C}" cy="${C}" r="${R-3}" fill="none" stroke="#fff" stroke-opacity=".6" stroke-width="4"/>${tk}<circle cx="${C}" cy="${C}" r="${screenR+6}" fill="#0B0F0D"/>`:'';
  const clip = full? `<rect width="824" height="824"/>` : `<circle cx="${C}" cy="${C}" r="${screenR}"/>`;
  const screen = full? `<rect width="824" height="824" fill="url(#scr)"/>` : `<circle cx="${C}" cy="${C}" r="${screenR}" fill="url(#scr)"/>`;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><g transform="translate(100 100)"><defs><clipPath id="box"><rect width="824" height="824" rx="185"/></clipPath><clipPath id="scrc">${clip}</clipPath>
<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset=".4" stop-color="#fff" stop-opacity="0"/></linearGradient>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${bg[0]}"/><stop offset="1" stop-color="${bg[1]}"/></linearGradient>
<linearGradient id="bez" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${bezel?bezel[0]:'#fff'}"/><stop offset="1" stop-color="${bezel?bezel[1]:'#fff'}"/></linearGradient>
<radialGradient id="scr" cx=".5" cy=".5" r="${full?'.7':'.5'}"><stop offset="0" stop-color="#11482A"/><stop offset=".8" stop-color="#062414"/><stop offset="1" stop-color="#020D07"/></radialGradient>
<linearGradient id="glass" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".22"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
<filter id="sh" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="26" stdDeviation="24" flood-color="#000" flood-opacity=".45"/></filter>
<filter id="bl" x="-200%" y="-200%" width="500%" height="500%"><feGaussianBlur stdDeviation="10"/></filter></defs>
<g clip-path="url(#box)"><rect width="824" height="824" fill="url(#bg)"/>${bez}${screen}
<g clip-path="url(#scrc)">
<g fill="none" stroke="#4DF07C" stroke-opacity=".22" stroke-width="5"><circle cx="${C}" cy="${C}" r="${ringR}"/><circle cx="${C}" cy="${C}" r="${ringR*2/3}"/><circle cx="${C}" cy="${C}" r="${ringR/3}"/><path d="M0 ${C} H824 M${C} 0 V824"/></g>
${trail}
<line x1="${C}" y1="${C}" x2="${lx}" y2="${ly}" stroke="#D6FFE0" stroke-width="9" stroke-linecap="round"/>
${blip(ringR*.78,32,20,1)}${blip(ringR*.55,-62,15,.6)}${blip(ringR*.6,150,14,.4)}
<circle cx="${C}" cy="${C}" r="16" fill="#D6FFE0"/>
${full?'':`<ellipse cx="${C}" cy="${C-screenR*.55}" rx="${screenR*.8}" ry="${screenR*.42}" fill="url(#glass)"/>`}</g>
<rect width="824" height="824" rx="185" fill="none" stroke="url(#sheen)" stroke-width="6"/></g></g></svg>`;
}
fs.writeFileSync('r1.svg',radar({bg:['#3A4250','#12161C'],bezel:['#F1F4F7','#7A8491'],R:304,screenR:250,ticks:true}));
fs.writeFileSync('r2.svg',radar({bg:['#F7F8FA','#AEB6C2'],bezel:['#4A515D','#16191F'],R:304,screenR:250,ticks:false}));
fs.writeFileSync('r3.svg',radar({bg:['#062414','#020D07'],bezel:null,R:0,screenR:412,ringR:330,ticks:false,full:true}));
