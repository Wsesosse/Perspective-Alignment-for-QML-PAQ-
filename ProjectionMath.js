.pragma library

// Camera axes: +X right, +Y down, +Z forward. Image origin: top left.
// Camera at world origin with identity orientation for M1 fixtures.
const EPS = 1e-12;
function norm(a) {
    if (!a || a.length !== 3 || a.some(v => !Number.isFinite(v))) return null;
    const n = Math.hypot(a[0], a[1], a[2]);
    return n > EPS ? a.map(v => v/n) : null;
}
function negate(a) { return [-a[0], -a[1], -a[2]]; }
function config(model, width, height, options) {
    const o=options || {};
    return {model:model, width:width, height:height,
            cx:o.cx === undefined ? width/2 : o.cx,
            cy:o.cy === undefined ? height/2 : o.cy,
            fx:o.fx === undefined ? 480 : o.fx,
            fy:o.fy === undefined ? 480 : o.fy,
            f:o.f === undefined ? Math.min(width,height)/Math.PI : o.f,
            fovDegrees:o.fovDegrees === undefined ? 180 : o.fovDegrees,
            tiltRadians:o.tiltRadians === undefined ? 0 : o.tiltRadians,
            near:o.near === undefined ? 1e-4 : o.near};
}
function validConfig(c) {
    return c && c.width>0 && c.height>0 && c.fx>0 && c.fy>0 && c.f>0
        && c.fovDegrees>0 && c.fovDegrees<=360 && c.near>0
        && [c.width,c.height,c.cx,c.cy,c.fx,c.fy,c.f,c.fovDegrees,
            c.tiltRadians,c.near].every(Number.isFinite);
}
function toCamera(v,c) {
    const a=c.tiltRadians || 0,co=Math.cos(a),si=Math.sin(a);
    return [v[0],co*v[1]-si*v[2],si*v[1]+co*v[2]];
}
function toWorld(v,c) {
    const a=c.tiltRadians || 0,co=Math.cos(a),si=Math.sin(a);
    return [v[0],co*v[1]+si*v[2],-si*v[1]+co*v[2]];
}
function inViewport(p,c) {
    return p.x >= 0 && p.x <= c.width && p.y >= 0 && p.y <= c.height;
}
function projectDirection(direction,c) {
    if (!validConfig(c)) return {kind:"invalid",reason:"Invalid camera/viewport"};
    const source=norm(direction);
    const d=source ? toCamera(source,c) : null;
    if (!d) return {kind:"invalid",reason:"Direction must be finite and nonzero"};
    if (c.model === "rectilinear") {
        const h=[c.cx*d[2]+c.fx*d[0],c.cy*d[2]+c.fy*d[1],d[2]];
        if (Math.abs(d[2]) <= EPS) {
            const n=Math.hypot(c.fx*d[0],c.fy*d[1]);
            return {kind:"mathematicalInfinity",homogeneous:[c.fx*d[0],c.fy*d[1],0],
                    directionPx:{x:c.fx*d[0]/n,y:c.fy*d[1]/n},
                    visibleInFOV:false,visibleInViewport:false};
        }
        const p={x:h[0]/h[2],y:h[1]/h[2]};
        return {kind:"finite",homogeneous:h,positionPx:p,
                visibleInFOV:d[2]>0,visibleInViewport:inViewport(p,c)};
    }
    if (c.model === "equidistantFisheye") {
        const rho=Math.hypot(d[0],d[1]);
        const theta=Math.atan2(rho,d[2]);
        const phi=rho>EPS ? Math.atan2(d[1],d[0]) : 0;
        const r=c.f*theta;
        const p={x:c.cx+r*Math.cos(phi),y:c.cy+r*Math.sin(phi)};
        const inside=theta <= c.fovDegrees*Math.PI/360 + 1e-10;
        return {kind:"finite",positionPx:p,thetaRad:theta,
                visibleInFOV:inside,visibleInViewport:inside && inViewport(p,c)};
    }
    if (c.model === "equirectangular") {
        const longitude=Math.atan2(d[0],d[2]);
        const latitude=Math.atan2(d[1],Math.hypot(d[0],d[2]));
        // +Y is down, so latitude increases down; wrap longitude at +/-pi.
        let x=c.cx+c.width*longitude/(2*Math.PI);
        if (x>=c.width) x-=c.width;
        if (x<0) x+=c.width;
        const p={x:x,y:c.cy+c.height*latitude/Math.PI};
        return {kind:"finite",positionPx:p,longitudeRad:longitude,
                latitudeRad:latitude,visibleInFOV:true,
                visibleInViewport:inViewport(p,c)};
    }
    return {kind:"invalid",reason:"Unknown projection model"};
}
function projectPoint(point,c) {
    if (!validConfig(c)) return {visible:false,reason:"Invalid camera/viewport"};
    const cameraPoint=point ? toCamera(point,c) : null;
    const d=norm(cameraPoint);
    if (!d) return {visible:false,reason:"Point at camera origin or invalid"};
    if (c.model==="rectilinear" && cameraPoint[2]<=c.near)
        return {visible:false,reason:"Behind near plane"};
    const p=projectDirection(point,c);
    return {visible:p.kind==="finite" && p.visibleInFOV,
            positionPx:p.positionPx,kind:p.kind,reason:p.reason};
}
function inverseDirection(pixel,c) {
    if (!validConfig(c) || !pixel
        || !Number.isFinite(pixel.x) || !Number.isFinite(pixel.y))
        return null;
    if (c.model==="rectilinear")
        return norm(toWorld([(pixel.x-c.cx)/c.fx,(pixel.y-c.cy)/c.fy,1],c));
    if (c.model==="equidistantFisheye") {
        const dx=pixel.x-c.cx,dy=pixel.y-c.cy;
        const r=Math.hypot(dx,dy), theta=r/c.f;
        if (theta>c.fovDegrees*Math.PI/360+1e-10 || theta>=Math.PI-EPS)
            return null;
        if (r<EPS) return norm(toWorld([0,0,1],c));
        return norm(toWorld([Math.sin(theta)*dx/r,Math.sin(theta)*dy/r,
                             Math.cos(theta)],c));
    }
    if (c.model==="equirectangular") {
        if (pixel.y<0 || pixel.y>c.height) return null;
        const lambda=2*Math.PI*(pixel.x-c.cx)/c.width;
        const epsilon=Math.PI*(pixel.y-c.cy)/c.height;
        return norm(toWorld([Math.sin(lambda)*Math.cos(epsilon),Math.sin(epsilon),
                             Math.cos(lambda)*Math.cos(epsilon)],c));
    }
    return null;
}
