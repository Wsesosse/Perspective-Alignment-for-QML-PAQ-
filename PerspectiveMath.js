.pragma library

// N-direction -> N-vanishing-point constraints for ONE 2D projective Item.
// Screen coordinates are relative to the Item; direction coordinates are local
// normalized axes (u = x / width - .5, v = y / height - .5).
// A single nonsingular homography maps all direction-at-infinity points onto
// one common vanishing line. Invalid inputs return identity + an error.

const EPS = 1e-9;
const VP_TOLERANCE = 1.5; // pixels

function identity() {
    return [1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1];
}

function fail(message) {
    return { valid: false, message: message, matrix: identity(),
             count: 0, maxError: 0 };
}

function dot(a, b) { return a.x * b.x + a.y * b.y; }
function cross(a, b) { return a.x * b.y - a.y * b.x; }
function length(a) { return Math.hypot(a.x, a.y); }
function distance(a, b) { return length({x: a.x-b.x, y: a.y-b.y}); }

function chooseLambda(dir, vp, center, width, height, scale) {
    const delta = { x: vp.x - center.x, y: vp.y - center.y };
    const target = { x: dir.x * width, y: dir.y * height };
    const dlen = length(delta);
    if (dlen < 2) return 0;
    const sign = dot(delta, target) < 0 ? -1 : 1;
    return sign * scale * length(target) / dlen;
}

function solve(width, height, specs, scaleFactor) {
    if (!(width > 0 && height > 0)) return fail('Item width/height must be positive');
    if (!specs || !specs.length) return {valid: true, message:'No VP subscriptions', matrix:identity(), count:0, maxError:0};

    const center = {x: width / 2, y: height / 2};
    const points = [];
    for (let i=0; i<specs.length; ++i) {
        const s=specs[i];
        if (!s || !s.direction || !s.vp ||
            !Number.isFinite(s.direction.x) || !Number.isFinite(s.direction.y) ||
            !Number.isFinite(s.vp.x) || !Number.isFinite(s.vp.y)) {
            return fail('Subscription ' + (i+1) + ': invalid direction or VP');
        }
        const mag=length(s.direction);
        if (mag < EPS) return fail('Subscription ' + (i+1) + ': direction is zero');
        const item={ d:{x:s.direction.x / mag, y:s.direction.y / mag},
                     v:{x:s.vp.x, y:s.vp.y} };
        let duplicate=false;
        for (const older of points) {
            if (Math.abs(cross(item.d, older.d)) < 1e-7) {
                if (distance(item.v, older.v) > VP_TOLERANCE)
                    return fail('Same source direction subscribed to different VPs');
                duplicate=true;
                break;
            }
        }
        if (!duplicate) points.push(item);
    }
    if (!points.length) return fail('No usable directions');

    const first=points[0];
    let second=null;
    for (let i=1; i<points.length; ++i) {
        if (Math.abs(cross(first.d,points[i].d)) > 1e-5) {
            second=points[i];
            break;
        }
    }
    if (!second && points.length > 1) return fail('No independent directions');
    if (second && distance(first.v,second.v) < 1)
        return fail('Different directions require distinct vanishing points');

    const factor = Math.max(0.05, Math.min(2, Number.isFinite(scaleFactor) ? scaleFactor : 1));
    let dir2 = second ? second.d : {x:-first.d.y, y:first.d.x};
    const determinant=cross(first.d,dir2);
    if (Math.abs(determinant) < 1e-7) return fail('Directions are not independent');

    let lambda1=chooseLambda(first.d,first.v,center,width,height,factor);
    let lambda2;
    let B;
    if (!lambda1) return fail('Vanishing point too close to Item center');
    if (second) {
        lambda2=chooseLambda(second.d,second.v,center,width,height,factor);
        if (!lambda2) return fail('Vanishing point too close to Item center');

        // For N >= 3, the third independent correspondence constrains the
        // ratio lambda2/lambda1. Remaining ones must agree with this ratio.
        for (const p of points) {
            if (p === first || p === second) continue;
            const relative={x:p.v.x-first.v.x,y:p.v.y-first.v.y};
            const baseline={x:second.v.x-first.v.x,y:second.v.y-first.v.y};
            const lineError=Math.abs(cross(relative,baseline))/length(baseline);
            if (lineError > VP_TOLERANCE)
                return fail('Subscribed VPs are not on one vanishing line (' + lineError.toFixed(1) + ' px)');
        }

        let ratioFixed=false;
        const baseline={x:second.v.x-first.v.x,y:second.v.y-first.v.y};
        const denom=dot(baseline,baseline);
        for (const p of points) {
            if (p === first || p === second) continue;
            const alpha=cross(p.d,dir2)/determinant;
            const beta=cross(first.d,p.d)/determinant;
            if (Math.abs(alpha) < 1e-7 || Math.abs(beta) < 1e-7) {
                const expected = Math.abs(beta) < 1e-7 ? first.v : second.v;
                if (distance(p.v,expected) > VP_TOLERANCE)
                    return fail('Parallel source directions mapped to inconsistent VPs');
                continue;
            }
            const t=dot({x:p.v.x-first.v.x,y:p.v.y-first.v.y},baseline)/denom;
            if (Math.abs(t) < 1e-7 || Math.abs(1-t) < 1e-7)
                return fail('A distinct source direction collapses onto another VP');
            lambda2=lambda1 * (alpha*t)/(beta*(1-t));
            if (!Number.isFinite(lambda2) || Math.abs(lambda2)<EPS)
                return fail('Degenerate scale required by VP constraints');
            ratioFixed=true;
            break;
        }
        B=[lambda2*second.v.x,lambda2*second.v.y,lambda2];
    } else {
        // A single VP constrains one local direction. The independent
        // perpendicular direction remains affine (its VP stays at infinity).
        B=[width*dir2.x*factor,height*dir2.y*factor,0];
    }

    const A=[lambda1*first.v.x,lambda1*first.v.y,lambda1];
    // The 3x3 homography columns U,V are determined by M*d1=A, M*d2=B.
    let U=[0,0,0], V=[0,0,0];
    for (let i=0;i<3;i++) {
        U[i]=(A[i]*dir2.y-B[i]*first.d.y)/determinant;
        V[i]=(-A[i]*dir2.x+B[i]*first.d.x)/determinant;
    }

    // All constraints use the same normalized local origin at Item center.
    // Uniformly scaling U,V preserves ALL exact vanishing point constraints.
    // Keep denominator away from zero on the entire rectangle.
    const maxOffset=(Math.abs(U[2])+Math.abs(V[2]))*0.5;
    const safe=maxOffset > 0.6 ? 0.6/maxOffset : 1;
    for (let i=0;i<3;i++) {U[i]*=safe; V[i]*=safe;}

    const j11=U[0]-center.x*U[2], j12=V[0]-center.x*V[2];
    const j21=U[1]-center.y*U[2], j22=V[1]-center.y*V[2];
    const jacobian=j11*j22-j12*j21;
    if (!Number.isFinite(jacobian) || Math.abs(jacobian) < 1e-4)
        return fail('Degenerate homography: Item lies on VP line or constraints collapse');
    // Reject mirrored/misordered mappings in this prototype to preserve UI
    // interaction and readability. A future API may expose flipping explicitly.
    if (jacobian < 0) return fail('VP ordering reverses the surface orientation');

    let maxError=0;
    for (const p of points) {
        const nx=U[0]*p.d.x+V[0]*p.d.y;
        const ny=U[1]*p.d.x+V[1]*p.d.y;
        const nw=U[2]*p.d.x+V[2]*p.d.y;
        if (Math.abs(nw)<1e-9) return fail('Expected finite VP mapped to infinity');
        const predicted={x:nx/nw,y:ny/nw};
        const error=distance(predicted,p.v);
        maxError=Math.max(maxError,error);
        if (!Number.isFinite(error) || error > VP_TOLERANCE)
            return fail('Incompatible subscription ' + (points.indexOf(p)+1) +
                        ': VP error '+error.toFixed(2)+' px');
    }

    // Convert from normalized local coordinates u,v to Qt local x,y.
    const matrix=[
        U[0]/width, V[0]/height, 0, center.x - 0.5*(U[0]+V[0]),
        U[1]/width, V[1]/height, 0, center.y - 0.5*(U[1]+V[1]),
        0,0,1,0,
        U[2]/width, V[2]/height, 0, 1 - 0.5*(U[2]+V[2])
    ];
    return { valid:true, message:'OK ('+points.length+' directions)',
             count:points.length, maxError:maxError, matrix:matrix };
}
