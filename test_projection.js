const fs=require('fs'), vm=require('vm'), assert=require('assert');
function load(file) {
    const code=fs.readFileSync(__dirname+'/'+file,'utf8').replace(/^\.pragma library\s*/,'');
    const ctx={Math,Number};
    vm.createContext(ctx); vm.runInContext(code,ctx); return ctx;
}
const P=load('ProjectionMath.js'), D=load('DirectionFamilies.js'),
      F=load('ProjectionFixtures.js');
const ref=JSON.parse(fs.readFileSync(__dirname+'/fixtures/reference_geometry.json'));
const c=P.config('rectilinear',900,560,{cx:450,cy:280,fx:480,fy:480});
assert.strictEqual(P.projectDirection([0,0,0],c).kind,'invalid');
assert.strictEqual(P.projectDirection([1,0,1],P.config('rectilinear',0,560)).kind,
                   'invalid');
const near=(a,b,tol=1e-8)=>assert(Math.abs(a-b)<tol,`${a} != ${b}`);
for(const family of ref.families.slice(0,2)) {
    const p=P.projectDirection(family.direction3D,c);
    near(p.positionPx.x,family.expectedVPPx[0]);
    near(p.positionPx.y,family.expectedVPPx[1]);
}
const infinity=P.projectDirection([0,1,0],c);
assert.strictEqual(infinity.kind,'mathematicalInfinity');
near(infinity.directionPx.x,0); near(infinity.directionPx.y,1);
const far=P.projectDirection([0,1,0.01],c);
assert.strictEqual(far.kind,'finite');
assert(far.positionPx.y>c.height);
assert.strictEqual(far.visibleInViewport,false);
const x=P.projectDirection([1,0,0],c), nx=P.projectDirection([-1,0,0],c);
assert(D.sameProjectiveVP(x.homogeneous,nx.homogeneous));
const finiteA=P.projectDirection([1,0,1],c);
const finiteB=P.projectDirection([-1,0,-1],c);
assert(D.sameProjectiveVP(finiteA.homogeneous,finiteB.homogeneous));
near(finiteA.positionPx.x,finiteB.positionPx.x);
const pair=D.pair({id:'X',direction3D:[1,0,0]});
near(pair.partnerDirection3D[0],-1);

const fish=P.config('equidistantFisheye',900,560,{f:560/Math.PI});
const center=P.projectDirection([0,0,1],fish);
near(center.positionPx.x,450); near(center.positionPx.y,280);
assert.strictEqual(P.projectDirection([0,0,-1],fish).visibleInFOV,false);
const rim=fish.f*Math.PI/2;
near(P.projectDirection([1,0,0],fish).positionPx.x,450+rim);
near(P.projectDirection([-1,0,0],fish).positionPx.x,450-rim);
near(P.projectDirection([0,1,0],fish).positionPx.y,280+rim);
for(const model of ['rectilinear','equidistantFisheye','equirectangular']) {
    const cfg=P.config(model,900,560,{fx:480,fy:480,f:560/Math.PI});
    for(const d of [[0.2,0.3,1],[-0.4,0.1,1],[0.3,-0.4,0.8]]) {
        const p=P.projectDirection(d,cfg);
        const back=P.inverseDirection(p.positionPx,cfg);
        const n=P.norm(d);
        for(let i=0;i<3;i++) near(back[i],n[i],1e-7);
    }
}
const sphere=P.config('equirectangular',900,560);
assert(P.projectDirection([0,0,-1],sphere).visibleInFOV);
assert(P.projectDirection([1,0,0],sphere).positionPx.x
       !== P.projectDirection([-1,0,0],sphere).positionPx.x);
for(const [key,model,count] of [
    ['1','rectilinear',3],['2','rectilinear',3],['3','rectilinear',3],
    ['4','equidistantFisheye',2],['5','equidistantFisheye',3],
    ['6','equirectangular',3],['N','rectilinear',8]
]) {
    const preset=F.preset(key);
    assert.strictEqual(preset.projection,model);
    assert.strictEqual(preset.families.length,count);
    assert(preset.families.every(f=>D.pair(f).valid));
}
const threePreset=F.preset('3');
const tilted=P.config('rectilinear',900,560,{
    fx:900*threePreset.focalScale,fy:900*threePreset.focalScale,
    tiltRadians:threePreset.cameraTiltRadians
});
const three=threePreset.families.map(f=>P.projectDirection(f.direction3D,tilted));
assert(three.every(v=>v.kind==='finite'));
const area=(three[1].positionPx.x-three[0].positionPx.x)
          *(three[2].positionPx.y-three[0].positionPx.y)
          -(three[1].positionPx.y-three[0].positionPx.y)
           *(three[2].positionPx.x-three[0].positionPx.x);
assert(Math.abs(area)>1e3,'3-point fixture must be non-collinear');
assert.strictEqual(P.projectDirection(F.preset('2').families[2].direction3D,c).kind,
                   'mathematicalInfinity');
assert.strictEqual(P.projectDirection(F.preset('3').families[2].direction3D,tilted).kind,
                   'finite');
assert(three.every(v=>v.visibleInViewport));
const tiltedPixel=P.projectDirection([0.3,0.2,1],tilted).positionPx;
const tiltedRoundtrip=P.inverseDirection(tiltedPixel,tilted);
for(let i=0;i<3;i++) near(tiltedRoundtrip[i],P.norm([0.3,0.2,1])[i],1e-7);
const five=F.preset('5').families[2];
assert.strictEqual(P.projectDirection(D.pair(five).partnerDirection3D,fish).visibleInFOV,
                   false);
console.log('PASS: reference VPs, true/far infinity, antipodes, fisheye rim, inverse, sphere');
