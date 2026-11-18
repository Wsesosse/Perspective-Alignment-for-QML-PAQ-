const fs=require('fs'),vm=require('vm'),assert=require('assert');
function load(file) {
 const code=fs.readFileSync(__dirname+'/'+file,'utf8').replace(/^\.pragma library\s*/,'');
 const ctx={Math,Number};vm.createContext(ctx);vm.runInContext(code,ctx);return ctx;
}
const P=load('ProjectionMath.js'),D=load('DirectionFamilies.js'),
      F=load('ProjectionFixtures.js'),S=load('SurfaceModelV2.js');
const near=(a,b,tol=1e-7)=>assert(Math.abs(a-b)<tol,`${a} != ${b}`);
for(const key of ['1','2','3','4','5','6','N']) {
 const fixture=F.preset(key),width=610,height=830;
 const c=P.config(fixture.projection,width,height,{
  fx:width*(fixture.focalScale||.33),fy:width*(fixture.focalScale||.33),
  f:Math.min(width,height)/Math.PI,
  tiltRadians:fixture.cameraTiltRadians||0
 });
 const snapshot={config:c,presetKey:key,revision:1,
  families:fixture.families.map(f=>({valid:true,direction3D:D.normalize(f.direction3D)}))};
 const mode=key==='2'||key==='3'?'crease':'planar';
 const params=S.parameters(snapshot,290,120,mode,.55);
 assert(params.valid,key);
 for(const t of [0,.25,.5,.75,1]) {
  const check=S.validate(params,t,P,16,8);
  assert(check.valid,`${key} t=${t}: ${check.diagnostic}`);
  if(c.model==='rectilinear')
   assert(check.maxGuideResidualPx<1e-6,`${key}: guide residual ${check.maxGuideResidualPx}`);
 }
 for(const u of [0,.2,.55,.8,1]) for(const v of [0,.5,1]) {
  const flat=S.screenPoint(params,u,v,0,P);
  near(flat.x,u*290);near(flat.y,v*120);
  const target=S.targetPoint(params,u,v,P);
  const endpoint=S.screenPoint(params,u,v,1,P);
  near(endpoint.x,target.x);near(endpoint.y,target.y);
 }
 // Same world line parameter and same camera generate material samples and guides.
 for(const [u0,u1,dir] of params.mode==='crease'
   ? [[0,.55,params.leftDir],[.55,1,params.rightDir]]
   : [[0,1,params.leftDir]]) {
  const origin=S.worldPoint(params,u0,.4);
  for(const u of [u0,(u0+u1)/2,u1]) {
   const guideWorld=S.vecAdd(origin,S.vecScale(dir,(u-u0)*params.scaleU));
   const a=P.projectPoint(guideWorld,c).positionPx;
   const b=S.targetPoint(params,u,.4,P);
   near(a.x-(c.cx-145),b.x);near(a.y-(c.cy-60),b.y);
  }
 }
 if(key==='1') {
  const vp=P.projectDirection(snapshot.families[0].direction3D,c);
  assert(vp.kind==='finite');
  for(const u of [.2,.5,.8]) {
   const a=S.targetPoint(params,u,0,P),b=S.targetPoint(params,u,1,P);
   const vx=vp.positionPx.x-(c.cx-145)-a.x;
   const vy=vp.positionPx.y-(c.cy-60)-a.y;
   near((b.x-a.x)*vy-(b.y-a.y)*vx,0,1e-6);
  }
 }
 if(mode==='crease') {
  assert(params.leftDir[2]*params.rightDir[2]<0,'crease needs different panel depth tangents');
  for(const v of [0,.25,.5,.75,1]) {
   const seam=S.worldPoint(params,.55,v);
   const expected=S.vecAdd(params.anchor,S.vecScale(params.verticalDir,
                                                  (v-.5)*params.scaleV));
   for(let k=0;k<3;k++) near(seam[k],expected[k]);
  }
 }
}
assert(!S.parameters(null,290,120,'crease',.55).valid);
console.log('PASS: 1–6/N constructed UI sheet, identity, seam, VP/guide alignment, transitions');
