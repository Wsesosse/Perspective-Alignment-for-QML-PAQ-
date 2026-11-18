.pragma library
function normalize(a) {
    if (!a || a.length!==3 || a.some(v=>!Number.isFinite(v))) return null;
    const n=Math.hypot(a[0],a[1],a[2]);
    return n>1e-12 ? a.map(v=>v/n) : null;
}
function pair(family) {
    const d=normalize(family.direction3D);
    if (!d) return {valid:false,reason:"Direction must be finite and nonzero"};
    return {valid:true,id:family.id,direction3D:d,
            partnerDirection3D:d.map(v=>-v)};
}
function sameProjectiveVP(a,b,tolerance) {
    const cross=[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],
                 a[0]*b[1]-a[1]*b[0]];
    return Math.hypot(...cross) <= (tolerance || 1e-9)
           * Math.hypot(...a)*Math.hypot(...b);
}
