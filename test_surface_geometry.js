// node test_surface_geometry.js
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const code = fs.readFileSync(__dirname + '/SurfaceGeometry.js', 'utf8')
    .replace(/^\.pragma library\s*/, '');
const ctx = {Math, Number};
vm.createContext(ctx);
vm.runInContext(code, ctx);

const W=440, H=230, c=0.55;
const corners=[
    {x:10,y:20}, {x:415,y:8},
    {x:20,y:213}, {x:410,y:225}
];
const seam=[{x:250,y:45},{x:205,y:205}];
const near=(a,b,tol=1e-9) => assert(Math.abs(a-b)<tol, `${a} != ${b}`);
const same=(a,b) => {near(a.x,b.x);near(a.y,b.y);};

for (const mode of ['corner','crease']) {
    for (const u of [0, 0.1, c, 0.7, 1])
        for (const v of [0, 0.3, 1])
            same(ctx.screenPoint(W,H,corners,seam,c,mode,u,v,0),
                 {x:W*u,y:H*v});
    for (const [u,v,target] of [
        [0,0,corners[0]],[1,0,corners[1]],
        [0,1,corners[2]],[1,1,corners[3]]
    ])
        same(ctx.screenPoint(W,H,corners,seam,c,mode,u,v,1), target);
    const result=ctx.validate(W,H,corners,seam,c,mode,1,16,8);
    assert(result.valid, result.diagnostic);
    assert.strictEqual(result.invertedTriangleCount,0);
}

const left=ctx.patchCorners(W,H,corners,seam,c,'crease','left');
const right=ctx.patchCorners(W,H,corners,seam,c,'crease','right');
for (const v of [0,0.125,0.5,0.875,1])
    same(ctx.bilinear(left,1,v),ctx.bilinear(right,0,v));
same(ctx.targetPoint(W,H,corners,seam,c,'crease',c,0),seam[0]);
same(ctx.targetPoint(W,H,corners,seam,c,'crease',c,1),seam[1]);
const leftSlope=ctx.bilinear(left,1,0).y-ctx.bilinear(left,0,0).y;
const rightSlope=ctx.bilinear(right,1,0).y-ctx.bilinear(right,0,0).y;
assert(Math.abs(leftSlope-rightSlope)>1, 'crease must have a kink');

const flipped=[corners[1],corners[0],corners[3],corners[2]];
assert(!ctx.validate(W,H,flipped,seam,c,'corner',1,16,8).valid);
assert(!ctx.validate(W,H,corners,[{x:NaN,y:0},seam[1]],c,'crease',1,16,8).valid);
console.log('PASS: identity, target corners, seam continuity, crease kink, geometry validity');
