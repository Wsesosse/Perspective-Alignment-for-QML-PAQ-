// node test_solver.js
const fs = require('fs');
const vm = require('vm');
const assert = require('assert');
const code = fs.readFileSync(__dirname + '/PerspectiveMath.js', 'utf8')
               .replace(/^\.pragma library\s*/,'');
const ctx = {Math, Number};
vm.createContext(ctx);
vm.runInContext(code, ctx);
const sub = (x,y,vx,vy) => ({direction:{x,y},vp:{x:vx,y:vy}});
const a={x:-500,y:-150},b={x:540,y:-150};
const mid=(m,n)=>({x:(m*a.x+n*b.x)/(m+n), y:(m*a.y+n*b.y)/(m+n)});
const subs=[sub(1,0,a.x,a.y),sub(0,1,b.x,b.y)];
for(let count=1;count<=8;count++){
 const list=subs.slice(0,Math.min(2,count));
 if(count>=3){const v=mid(1,1);list.push(sub(1,1,v.x,v.y));}
 for(let i=4;i<=count;i++){const m=i-1,n=2;const v=mid(m,n);list.push(sub(m,n,v.x,v.y));}
 const out=ctx.solve(240,100,list,0.8);
 assert(out.valid, `count ${count}: ${out.message}`);
 assert(out.maxError<1e-6, `count ${count}: error ${out.maxError}`);
 assert(out.matrix.length===16);
}
let out=ctx.solve(240,100,[subs[0],subs[1],sub(1,1,20,-105)],0.8);
assert(!out.valid && out.message.includes('vanishing line'));
out=ctx.solve(240,100,[subs[0],subs[1],sub(1,1,20,-150)],0.8);
assert(out.valid); // third collinear VP fixes the lambda ratio
const fourth=mid(3,2);
const compatible4=ctx.solve(240,100,[subs[0],subs[1],sub(1,1,120,-150),sub(3,2,fourth.x,fourth.y)],0.8);
assert(!compatible4.valid); // third's lambda ratio conflicts with fourth
const sameDir=ctx.solve(240,100,[sub(1,0,-500,-150),sub(2,0,500,-150)],1);
assert(!sameDir.valid);
console.log('PASS: 1..8 consistent VPs, 3rd ratio, 4th mismatch, noncollinear VP, duplicate-direction conflict');
