.pragma library

function vecAdd(a,b) { return [a[0]+b[0],a[1]+b[1],a[2]+b[2]]; }
function vecScale(a,s) { return [a[0]*s,a[1]*s,a[2]*s]; }
function mix(a,b,t) { return {x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t}; }
function smoothstep(t) { const x=Math.max(0,Math.min(1,t));return x*x*(3-2*x); }
function parameters(snapshot,width,height,mode,creaseU) {
    if(!snapshot || !snapshot.config || !(width>0 && height>0)
       || !(creaseU>0 && creaseU<1)
       || (mode!=="planar" && mode!=="crease"))
        return {valid:false,diagnostic:"Invalid scene or surface parameters"};
    const c=snapshot.config, families=snapshot.families;
    if(!families || families.length<2 || !families[0].valid || !families[1].valid)
        return {valid:false,diagnostic:"Need two valid direction families"};
    const z=6, a=c.tiltRadians || 0;
    const anchor=[0,z*Math.sin(a),z*Math.cos(a)];
    const first=families[0].direction3D;
    let second=families[1].direction3D;
    let vertical=families.length>=3 && families[2].valid
        ? families[2].direction3D : second;
    // In 2/3-point fixtures, two horizontal families form adjacent sheet
    // panels. Right material derivative uses -d2: same projective VP as d2.
    const horizontalPair=snapshot.presetKey==="2" || snapshot.presetKey==="3";
    const onePoint=snapshot.presetKey==="1";
    if(onePoint) anchor[1]=2.5;
    const leftDir=onePoint ? second : first;
    const rightDir=horizontalPair ? second.map(v=>-v) : leftDir;
    if(onePoint) vertical=first.map(v=>-v);
    else if(!horizontalPair) vertical=second;
    const actualMode=mode==="crease" && horizontalPair ? "crease" : "planar";
    let scaleU,scaleV;
    if(c.model==="rectilinear") {
        scaleU=width*z/c.fx; scaleV=height*z/c.fy;
    } else if(c.model==="equidistantFisheye") {
        scaleU=width*z/c.f; scaleV=height*z/c.f;
    } else if(c.model==="equirectangular") {
        scaleU=width*2*Math.PI*z/c.width;
        scaleV=height*Math.PI*z/c.height;
    } else return {valid:false,diagnostic:"Unknown projection model"};
    if(onePoint || snapshot.presetKey==="3") {
        scaleU*=0.7;
        scaleV*=0.7;
    }
    if(onePoint) scaleV*=3;
    return {valid:true,mode:actualMode,anchor:anchor,leftDir:leftDir,
            rightDir:rightDir,verticalDir:vertical,scaleU:scaleU,scaleV:scaleV,
            creaseU:creaseU,config:c,width:width,height:height,
            revision:snapshot.revision};
}
function worldPoint(p,u,v) {
    const useRight=p.mode==="crease" && u>=p.creaseU;
    const uOrigin=p.mode==="crease" ? p.creaseU : 0.5;
    const du=useRight ? p.rightDir : p.leftDir;
    return vecAdd(vecAdd(p.anchor,vecScale(du,(u-uOrigin)*p.scaleU)),
                  vecScale(p.verticalDir,(v-0.5)*p.scaleV));
}
function targetPoint(p,u,v,projection) {
    const projected=projection.projectPoint(worldPoint(p,u,v),p.config);
    if(!projected.visible || !projected.positionPx) return null;
    return {x:projected.positionPx.x-(p.config.cx-p.width/2),
            y:projected.positionPx.y-(p.config.cy-p.height/2)};
}
function screenPoint(p,u,v,t,projection) {
    const target=targetPoint(p,u,v,projection);
    if(!target) return null;
    return mix({x:u*p.width,y:v*p.height},target,smoothstep(t));
}
function area(a,b,c) {
    return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x);
}
function validate(p,t,projection,columns,rows) {
    if(!p.valid || !(t>=0 && t<=1) || !Number.isFinite(t))
        return {valid:false,diagnostic:p.diagnostic || "Invalid transition",
                invertedTriangleCount:0};
    const seam=p.mode==="crease" ? p.creaseU : 0.5;
    let bad=0,hidden=0,maxGuideResidualPx=0;
    for(let side=0;side<2;side++) {
        const u0=side===0 ? 0 : seam,u1=side===0 ? seam : 1;
        const nx=Math.max(1,Math.round(columns*(u1-u0)));
        for(let y=0;y<rows;y++) for(let x=0;x<nx;x++) {
            const a=screenPoint(p,u0+(u1-u0)*x/nx,y/rows,t,projection);
            const b=screenPoint(p,u0+(u1-u0)*(x+1)/nx,y/rows,t,projection);
            const c=screenPoint(p,u0+(u1-u0)*x/nx,(y+1)/rows,t,projection);
            const d=screenPoint(p,u0+(u1-u0)*(x+1)/nx,(y+1)/rows,t,projection);
            if(!a || !b || !c || !d) {hidden++;continue;}
            if(![a,b,c,d].every(q=>Number.isFinite(q.x)&&Number.isFinite(q.y))
               || area(a,b,c)<=1e-6 || area(b,d,c)<=1e-6) bad++;
        }
        if(p.config.model==="rectilinear") {
            const direction=side===0 ? p.leftDir : p.rightDir;
            const vp=projection.projectDirection(direction,p.config);
            for(const v of [0,0.5,1]) {
                const a=targetPoint(p,u0,v,projection);
                const b=targetPoint(p,u1,v,projection);
                if(!a || !b) continue;
                const dx=b.x-a.x,dy=b.y-a.y;
                let residual;
                if(vp.kind==="finite") {
                    const vx=vp.positionPx.x-(p.config.cx-p.width/2)-a.x;
                    const vy=vp.positionPx.y-(p.config.cy-p.height/2)-a.y;
                    const n=Math.hypot(vx,vy);
                    residual=n>1e-9 ? Math.abs(dx*vy-dy*vx)/n : Infinity;
                } else if(vp.kind==="mathematicalInfinity") {
                    const g=vp.directionPx;
                    residual=Math.abs(dx*g.y-dy*g.x);
                } else residual=Infinity;
                maxGuideResidualPx=Math.max(maxGuideResidualPx,residual);
            }
        }
    }
    return {valid:bad===0 && hidden===0,
            diagnostic:hidden ? hidden+" cells outside camera FOV"
                      : bad ? bad+" inverted/degenerate cells" : "OK (constructed 3D sheet)",
            invertedTriangleCount:bad*2,hiddenCellCount:hidden,
            maxGuideResidualPx:p.config.model==="rectilinear" ? maxGuideResidualPx : NaN};
}
