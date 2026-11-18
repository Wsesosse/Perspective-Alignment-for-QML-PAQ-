.pragma library
function addLinePoint(a,d,s) {
    return [a[0]+s*d[0],a[1]+s*d[1],a[2]+s*d[2]];
}
function sampleLine(origin,direction,config,projection,steps,s0,s1) {
    const count=steps || 48, first=s0===undefined ? -2.5 : s0;
    const last=s1===undefined ? 2.5 : s1;
    const segments=[];
    let current=[];
    for(let i=0;i<=count;i++) {
        const s=first+(last-first)*i/count;
        const world=addLinePoint(origin,direction,s);
        const result=projection.projectPoint(world,config);
        const p=result.positionPx;
        // Clip at camera/FOV boundaries. Screen-edge clipping remains to viewport item.
        if(!result.visible || !p || !Number.isFinite(p.x) || !Number.isFinite(p.y)) {
            if(current.length>1) segments.push(current);
            current=[];
            continue;
        }
        if(config.model==="equirectangular" && current.length
           && Math.abs(p.x-current[current.length-1].x)>config.width/2) {
            if(current.length>1) segments.push(current);
            current=[];
        }
        current.push({x:p.x,y:p.y,s:s});
    }
    if(current.length>1) segments.push(current);
    return segments;
}
function projectFamily(family,config,projection) {
    const origins=family.guideOrigins || [
        [-1.2,-0.8,6],[-1.2,0.8,6],[1.2,-0.8,6],[1.2,0.8,6]
    ];
    return origins.map((origin,i)=>({
        familyId:family.id,member:i,origin3D:origin,
        segments:sampleLine(origin,family.direction3D,config,projection,96,-20,20)
    }));
}
function lineThroughPointAndVP(p,v) {
    const h=v.homogeneous;
    return {a:p.y*h[2]-h[1], b:h[0]-p.x*h[2],
            c:p.x*h[1]-p.y*h[0]};
}
function lineResidualPx(line,p) {
    const n=Math.hypot(line.a,line.b);
    return n>1e-12 ? Math.abs(line.a*p.x+line.b*p.y+line.c)/n : Infinity;
}
function effectiveInfinity(vp,anchors,lengthLogical,angleToleranceRad,
                           pixelTolerancePhysical,dpr) {
    if(!(lengthLogical>0) || !(angleToleranceRad>=0)
       || !(pixelTolerancePhysical>=0) || !(dpr>0)
       || ![lengthLogical,angleToleranceRad,pixelTolerancePhysical,dpr]
           .every(Number.isFinite))
        return {kind:"invalid",reason:"Invalid evaluation tolerances or DPR"};
    if(vp.kind==="mathematicalInfinity")
        return {kind:"mathematicalInfinity",thetaMaxRad:0,errorPhysicalPx:0};
    if(vp.kind!=="finite" || !vp.positionPx || anchors.length<2)
        return {kind:"invalid",reason:"Need finite VP and at least two anchors"};
    const V=vp.positionPx, vectors=[];
    for(const p of anchors) {
        const dx=V.x-p.x,dy=V.y-p.y,n=Math.hypot(dx,dy);
        if(n<1e-12) return {kind:"invalid",reason:"VP equals guide anchor"};
        vectors.push([dx/n,dy/n]);
    }
    let theta=0;
    for(let i=0;i<vectors.length;i++) for(let j=i+1;j<vectors.length;j++) {
        const a=vectors[i],b=vectors[j];
        theta=Math.max(theta,Math.atan2(Math.abs(a[0]*b[1]-a[1]*b[0]),
                                        Math.abs(a[0]*b[0]+a[1]*b[1])));
    }
    // Reference = normalized unoriented mean, with sign aligned to first.
    let sx=0,sy=0;
    for(const v of vectors) {
        const sign=v[0]*vectors[0][0]+v[1]*vectors[0][1]<0 ? -1 : 1;
        sx+=sign*v[0]; sy+=sign*v[1];
    }
    const n=Math.hypot(sx,sy);
    if(n<1e-12) return {kind:"invalid",reason:"Guide reference undefined"};
    const ref=[sx/n,sy/n];
    let error=0;
    for(const v of vectors)
        error=Math.max(error,lengthLogical*Math.abs(ref[0]*v[1]-ref[1]*v[0])
                       *(dpr || 1));
    return {kind:theta<=angleToleranceRad && error<=pixelTolerancePhysical
                 ? "effectiveInfinity" : "finite",
            thetaMaxRad:theta,errorPhysicalPx:error};
}
function curveStraightness(segments,angleToleranceRad,pixelTolerancePhysical,dpr) {
    if(!(angleToleranceRad>=0) || !(pixelTolerancePhysical>=0) || !(dpr>0)
       || ![angleToleranceRad,pixelTolerancePhysical,dpr].every(Number.isFinite))
        return {kind:"invalid",reason:"Invalid curve tolerances or DPR"};
    let thetaMax=0,errorMax=0,used=0;
    for(const segment of segments) {
        if(segment.length<3) continue;
        const a=segment[0],b=segment[segment.length-1];
        const dx=b.x-a.x,dy=b.y-a.y,len=Math.hypot(dx,dy);
        if(len<=1e-12) continue;
        const tangents=[];
        for(let i=1;i<segment.length;i++) {
            const vx=segment[i].x-segment[i-1].x;
            const vy=segment[i].y-segment[i-1].y;
            const n=Math.hypot(vx,vy);
            if(n>1e-12) tangents.push([vx/n,vy/n]);
        }
        for(let i=0;i<tangents.length;i++) for(let j=i+1;j<tangents.length;j++) {
            const p=tangents[i],q=tangents[j];
            thetaMax=Math.max(thetaMax,
                Math.atan2(Math.abs(p[0]*q[1]-p[1]*q[0]),
                           Math.abs(p[0]*q[0]+p[1]*q[1])));
        }
        for(const p of segment)
            errorMax=Math.max(errorMax,
                Math.abs(dx*(p.y-a.y)-dy*(p.x-a.x))/len*dpr);
        used++;
    }
    if(!used) return {kind:"invalid",reason:"Need visible curve with three samples"};
    return {kind:thetaMax<=angleToleranceRad && errorMax<=pixelTolerancePhysical
                 ? "effectiveStraight" : "curved",
            thetaMaxRad:thetaMax,errorPhysicalPx:errorMax};
}
