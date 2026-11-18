const fs=require('fs'),vm=require('vm'),assert=require('assert');
function load(file) {
 const code=fs.readFileSync(__dirname+'/'+file,'utf8').replace(/^\.pragma library\s*/,'');
 const ctx={Math,Number};vm.createContext(ctx);vm.runInContext(code,ctx);return ctx;
}
const P=load('ProjectionMath.js'),G=load('GuideConstruction.js'),F=load('ProjectionFixtures.js');
const c=P.config('rectilinear',900,560,{fx:480,fy:480});
for(const d of [[1,0,1],[0,1,0]]) {
 const vp=P.projectDirection(d,c);
 const members=G.projectFamily({id:'test',direction3D:P.norm(d)},c,P);
 assert(members.length>=2);
 for(const member of members) for(const segment of member.segments) {
  const line=G.lineThroughPointAndVP(segment[0],vp);
  for(const point of segment)
   assert(G.lineResidualPx(line,point)<1e-7);
 }
}
const tilted=P.config('rectilinear',900,560,{fx:198,fy:198,tiltRadians:.8});
const verticalVP=P.projectDirection([0,1,0],tilted);
assert.strictEqual(verticalVP.kind,'finite');
for(const member of G.projectFamily({id:'vertical',direction3D:[0,1,0]},tilted,P))
 for(const segment of member.segments) {
  const line=G.lineThroughPointAndVP(segment[0],verticalVP);
  for(const point of segment) assert(G.lineResidualPx(line,point)<1e-7);
 }
const fish=P.config('equidistantFisheye',900,560,{f:560/Math.PI});
const origin=[-1.2,0.8,6],d=[1,0,0];
const segments=G.sampleLine(origin,d,fish,P,32,-2,2);
assert(segments.length>0);
for(const segment of segments) for(const point of segment) {
 const actual=P.projectPoint(G.addLinePoint(origin,d,point.s),fish);
 assert(Math.hypot(point.x-actual.positionPx.x,point.y-actual.positionPx.y)<1e-8);
}
const curved=G.curveStraightness(segments,Math.PI/1800,.5,1);
assert.strictEqual(curved.kind,'curved');
assert(curved.thetaMaxRad>0 && curved.errorPhysicalPx>0);
const straight=G.curveStraightness(
 G.sampleLine([-1.2,0,6],d,fish,P,32,-2,2),Math.PI/1800,.5,1);
assert.strictEqual(straight.kind,'effectiveStraight');
assert.strictEqual(G.curveStraightness(segments,Math.PI/1800,.5,2).kind,'curved');
const longArc=G.sampleLine(origin,d,fish,P,256,-1000,1000)[0];
const negative=P.projectDirection([-1,0,0],fish).positionPx;
const positive=P.projectDirection([1,0,0],fish).positionPx;
assert(Math.hypot(longArc[0].x-negative.x,longArc[0].y-negative.y)<3);
assert(Math.hypot(longArc.at(-1).x-positive.x,longArc.at(-1).y-positive.y)<3);
const sphere=P.config('equirectangular',900,560);
const seam=G.sampleLine([0,0,-6],[1,0,0],sphere,P,64,-2,2);
assert(seam.length>=2,'longitude seam must split path');
for(const segment of seam) for(let i=1;i<segment.length;i++)
 assert(Math.abs(segment[i].x-segment[i-1].x)<sphere.width/2);

const anchors=[{x:0,y:-35},{x:0,y:35}], angle=Math.PI/1800;
function metric(d,dpr=1,tol=.5) {
 return G.effectiveInfinity({kind:'finite',positionPx:{x:235+d,y:0}},
                            anchors,235,angle,tol,dpr);
}
assert.strictEqual(metric(10).kind,'finite');
assert.strictEqual(metric(10000).kind,'finite');
assert.strictEqual(metric(40000).kind,'effectiveInfinity');
assert.strictEqual(metric(40000,2,.3).kind,'finite');
assert.strictEqual(G.effectiveInfinity(
 {kind:'finite',positionPx:{x:40235,y:0}},anchors,1000,angle,.5,1).kind,
 'finite');
assert.strictEqual(G.effectiveInfinity({kind:'mathematicalInfinity'},
 anchors,235,angle,.5,1).kind,'mathematicalInfinity');
assert.strictEqual(G.effectiveInfinity(
 {kind:'finite',positionPx:{x:500,y:0}},anchors,235,angle,.5,0).kind,
 'invalid');
assert.strictEqual(G.lineResidualPx({a:0,b:0,c:0},{x:1,y:2}),Infinity);
const eight=F.preset('N');
assert.strictEqual(eight.families.length,8);
assert(eight.families.every(f=>G.projectFamily(f,c,P).length>=2));
console.log('PASS: projected parallel guides, fisheye samples, spherical seam, effective infinity, N=8');
