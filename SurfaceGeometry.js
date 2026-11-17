.pragma library

// Material coordinates are always (u,v); this screenWarp target stays separate
// from any future zero-thickness 3D surface embedding and camera projection.
function point(x, y) { return {x: x, y: y}; }
function mix(a, b, t) { return point(a.x + (b.x-a.x)*t, a.y + (b.y-a.y)*t); }
function smoothstep(t) {
    const s = Math.max(0, Math.min(1, t));
    return s*s*(3-2*s);
}
function bilinear(c, u, v) {
    return mix(mix(c[0], c[1], u), mix(c[2], c[3], u), v);
}
function patchCorners(width, height, corners, seam, creaseU, mode, side) {
    const c = corners && corners.length === 4 ? corners
            : [point(0,0), point(width,0), point(0,height), point(width,height)];
    const upper = mode === "crease" && seam && seam.length === 2
                ? seam[0] : mix(c[0], c[1], creaseU);
    const lower = mode === "crease" && seam && seam.length === 2
                ? seam[1] : mix(c[2], c[3], creaseU);
    return side === "left" ? [c[0], upper, c[2], lower]
                           : [upper, c[1], lower, c[3]];
}
function sourcePoint(width, height, u, v) { return point(width*u, height*v); }
function targetPoint(width, height, corners, seam, creaseU, mode, u, v) {
    const left = u <= creaseU;
    const c = patchCorners(width, height, corners, seam, creaseU, mode,
                           left ? "left" : "right");
    const localU = left ? u/creaseU : (u-creaseU)/(1-creaseU);
    return bilinear(c, localU, v);
}
function screenPoint(width, height, corners, seam, creaseU, mode, u, v, transition) {
    return mix(sourcePoint(width, height, u, v),
               targetPoint(width, height, corners, seam, creaseU, mode, u, v),
               smoothstep(transition));
}
function signedDoubleArea(a, b, c) {
    return (b.x-a.x)*(c.y-a.y) - (b.y-a.y)*(c.x-a.x);
}
function validate(width, height, corners, seam, creaseU, mode, transition,
                  columns, rows) {
    if (!(width > 0 && height > 0) || !(creaseU > 0 && creaseU < 1)
        || !Number.isFinite(transition) || transition < 0 || transition > 1
        || (mode !== "corner" && mode !== "crease")
        || !Number.isInteger(columns) || columns < 2
        || !Number.isInteger(rows) || rows < 1
        || !corners || corners.length !== 4
        || (mode === "crease" && (!seam || seam.length !== 2)))
        return {valid:false, diagnostic:"Invalid surface parameters", invertedTriangleCount:0};
    const points = mode === "crease" ? corners.concat(seam) : corners;
    if (points.some(p => !p || !Number.isFinite(p.x) || !Number.isFinite(p.y)))
        return {valid:false, diagnostic:"Non-finite target point", invertedTriangleCount:0};
    let bad = 0;
    const leftCols = Math.max(1, Math.min(columns-1, Math.round(columns*creaseU)));
    for (let side=0; side<2; ++side) {
        const start = side === 0 ? 0 : creaseU;
        const end = side === 0 ? creaseU : 1;
        const count = side === 0 ? leftCols : columns-leftCols;
        for (let y=0; y<rows; ++y) for (let x=0; x<count; ++x) {
            const u0=start+(end-start)*x/count, u1=start+(end-start)*(x+1)/count;
            const v0=y/rows, v1=(y+1)/rows;
            const a=screenPoint(width,height,corners,seam,creaseU,mode,u0,v0,transition);
            const b=screenPoint(width,height,corners,seam,creaseU,mode,u1,v0,transition);
            const c=screenPoint(width,height,corners,seam,creaseU,mode,u0,v1,transition);
            const d=screenPoint(width,height,corners,seam,creaseU,mode,u1,v1,transition);
            if (signedDoubleArea(a,b,c) <= 1e-6 || signedDoubleArea(b,d,c) <= 1e-6) ++bad;
        }
    }
    return {valid:bad === 0, diagnostic:bad ? bad+" inverted/degenerate cells" : "OK",
            invertedTriangleCount:bad*2};
}
