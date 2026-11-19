import fs from 'fs';
const C=9, f=n=>+n.toFixed(2);
const pt=(r,a)=>{const t=(a-90)*Math.PI/180;return [f(C+r*Math.cos(t)),f(C+r*Math.sin(t))]};
// Same angles as the app icon (gen-radar.mjs): lead 60°, trail 80°, blips at 32°, -62°, 150°.
function screen(R,{tint,cross}){
  let s='';
  if(tint) s+=`<circle cx="9" cy="9" r="${R}" fill="currentColor" opacity="${tint}"/>`;
  if(cross) s+=`<path d="M${f(C-R)} 9H${f(C+R)}M9 ${f(C-R)}V${f(C+R)}" stroke="currentColor" stroke-width=".6" opacity=".45"/>`;
  const N=14;for(let i=0;i<N;i++){const [x0,y0]=pt(R,60-80*(1-i/N)),[x1,y1]=pt(R,60);s+=`<path d="M9 9L${x0} ${y0}A${R} ${R} 0 0 1 ${x1} ${y1}Z" fill="currentColor" opacity=".058"/>`;}
  const [lx,ly]=pt(R,60);s+=`<path d="M9 9L${lx} ${ly}" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/>`;
  const b=(r,a,s2,o)=>{const [x,y]=pt(R*r,a);return `<circle cx="${x}" cy="${y}" r="${s2}" fill="currentColor" opacity="${o}"/>`};
  s+=b(.74,32,1.05,1)+b(.55,-62,.75,.7)+b(.6,150,.7,.5)+`<circle cx="9" cy="9" r=".8" fill="currentColor"/>`;
  return s;
}
function ticks(r0,r1){let s='';for(let a=0;a<360;a+=45){const [x0,y0]=pt(r0,a),[x1,y1]=pt(r1,a);s+=`<path d="M${x0} ${y0}L${x1} ${y1}"/>`;}return s;}
export const glyphs={
  tileTint:`<mask id="M"><rect width="18" height="18" fill="#fff"/><circle cx="9" cy="9" r="6.1" fill="#000"/></mask><rect x="1.25" y="1.25" width="15.5" height="15.5" rx="3.6" fill="currentColor" mask="url(#M)"/>${screen(5.2,{tint:.28,cross:false})}`,
  tileClear:`<mask id="M"><rect width="18" height="18" fill="#fff"/><circle cx="9" cy="9" r="6.3" fill="#000"/></mask><rect x="1.25" y="1.25" width="15.5" height="15.5" rx="3.6" fill="currentColor" mask="url(#M)"/>${screen(5.6,{tint:0,cross:true})}`,
  bezelTint:`<circle cx="9" cy="9" r="7.6" fill="none" stroke="currentColor" stroke-width="1.5"/>${screen(6.1,{tint:.3,cross:false})}`,
  bezelTicks:`<circle cx="9" cy="9" r="7.6" fill="none" stroke="currentColor" stroke-width="1.5"/><g stroke="currentColor" stroke-width=".8" opacity=".55">${ticks(5.9,6.6)}</g>${screen(5.6,{tint:0,cross:true})}`,
};
