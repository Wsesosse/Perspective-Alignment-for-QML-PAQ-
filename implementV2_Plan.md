# PAQ — Perspective Implementation V2 Plan

> Status: **DESIGN / IMPLEMENTATION PLAN, not completed functionality**  
> Repository: `Wsesosse/Perspective-Alignment-for-QML-PAQ-`, branch `prototype`  
> Date: 2026-11-17  
> Purpose: Fix the geometric foundation **before** adding further UI distortion.

## 0. Objective and definition of done

**PAQ = Perspective Alignment for QML.** It deforms **an existing QML UI sheet** (for example, a Button/TextField) according to a mathematically defined perspective construction. Apparent depth may come from projecting a bent/folded **zero-thickness material surface**; the implementation must not invent walls, thickness, or a boxed UI.

This version must build perspective from:
1. **Projection model and viewing directions**
2. **Paired/opposite vanishing directions**
3. **Real construction guide lines or curves**
4. **Surface points/edges constrained to that construction**
5. **Rendering and input remapping of the same UI content**

**No more random VP placement, arbitrary Bezier curves between markers, or treating VP coordinates as a force pulling vertices.** A screenshot that looks distorted is not proof of correct perspective.

## 1. Current code baseline (verified in `prototype`)

| File | Existing function | Limitation |
|---|---|---|
| `PerspectiveMath.js` | Exact direction-to-VP constraints for **one planar homography**; checks a common vanishing line | Correct rejection within its limited domain; **not** a universal N-VP surface solver |
| `PerspectiveItem.qml` | Single homography transforms a QML Item | Cannot bend or model multiple local patch orientations |
| `PerspectiveSurface.qml` | Three modes; one content source; two shader patches for corner/crease; planar shader separately | Planar uses VP constraints, while corner/crease use manually specified targets, not VP construction |
| `SurfaceGeometry.js` | Bilinear target corners, seam continuity, triangle validity, smoothstep | Does not derive the geometry from a projection model / guide curves |
| `shaders/planar.vert`, `shaders/surface.vert` | Current planar and piecewise texture warps | Shader geometry is not proof that guides, directions or pairing are correct |
| `SurfaceDemo.qml` | Drag VP markers or corner/seam target handles | No faithful guide-curve construction overlay or numerical guide alignment test |
| `test_solver.js`, `test_surface_geometry.js` | Existing mathematical checks | Do not validate projected 3D line families, antipodal pairs, or 3-VP multi-patch geometry |

**Preserve the existing working features.** The executable target remains `PerspectiveNVPApp` (avoid a collision with Qt's generated `PerspectiveNVP/` directory). Keep the old planar solver as a named, constrained specialization. Do **not** remove its collinearity check to pretend non-coplanar directions fit a single homography.

## 2. Core theory, with exact scope

### 2.1 A vanishing point comes from a direction, not from a UI vertex

For a central camera, a world-space parallel-line family has direction `d` (unit 3-vector). In rectilinear/pinhole homogeneous coordinates:

$$
\mathbf v \sim K R\mathbf d
$$

Variables:
- `d = (d_x,d_y,d_z)`: a **3D direction**, in world coordinates.
- `R`: world-to-camera rotation.
- `K`: camera intrinsics.
- `v`: homogeneous projected vanishing point.
- `~`: equality up to a nonzero homogeneous scale.

For camera coordinates oriented with **positive z forward**, a simple pinhole projection of a **visible** 3D point `p = (x,y,z)`, `z>0`, is:

$$
P_{\mathrm{rect}}(p) =
(c_x+f_x x/z,\ c_y+f_y y/z)
$$

`c_x,c_y` are principal-point screen coordinates (pixels), `f_x,f_y` are focal lengths in pixel units. For a direction `d` replace `p` by `d` when `d_z\ne0`; in homogeneous projective space `d` and `-d` map to the **same** VP. At `d_z=0`, the rectilinear VP is **at infinity** and corresponding image lines are parallel. Never confuse a VP at infinity with a spherical antipode hidden behind the observer.

A single **planar** homography maps all in-plane direction-at-infinity points to one common vanishing line (which may be slanted; it is NOT necessarily screen-horizontal). A 3rd non-collinear target VP cannot be forced into that *same planar homography*. Other patches of a folded/bent sheet may have different local tangent planes and different vanishing lines.

### 2.2 Pairing is a relationship between opposite directions

Represent a pair as `d` and `-d` (**antipodal directions**), with one shared direction-family identity. This is not "VP1 pairs with VP2 because they are adjacent".

- **Full sphere:** two distinct antipodal positions on the sphere of directions, separated by 180 degrees.
- **Front-hemisphere fisheye:** the opposite partner can be outside the visible field; it still exists as a **direction**, not necessarily a visible marker.
- **Rectilinear projective image:** opposite directions correspond to the *same homogeneous vanishing point* (`[v]=[-v]`).
- **VP at infinity:** occurs when a direction is parallel to the image plane (`d_z=0`); not a blanket explanation for a hidden partner.

Do not enforce visual pairing by connecting arbitrary two on-screen VP markers. First identify the world directions, then project them. A freely dragged marker in a model with a valid inverse can change `d`; recompute the opposite partner as `-d`, and label the partner "offscreen"/"outside FOV" as needed. The screen positions of the pair are **derived**, not independently draggable without constraint.

### 2.3 Guide lines/curves must come from the same projection as the object

For each line family `i` choose:
- a direction `d_i` (3D unit vector),
- actual 3D **parallel** line members with different offsets `a_{ij}`,
- a shared projection `P`.

A line member is

$$
L_{ij}(s)=a_{ij}+s\,d_i,\qquad s\in\mathbb R.
$$

Its **projected guide** is

$$
G_{ij}(s)=P(L_{ij}(s)).
$$

- In **rectilinear projection**, each visible segment of `G` is a straight line, passing through its direction's finite VP (or parallel if its VP is at infinity).
- In **spherical/fisheye projection**, a 3D straight line generally projects to a **curve**; its complete angular direction ends approach `d_i` and `-d_i`. Only display portions in the selected FOV.
- For a 3D material surface `S(u,v)`, projected surface directions/edges must be rendered through **the same** `P`. Overlay guides are diagnostics and must not be a separately guessed decorative grid.
- A **curved material line** on a deforming sheet is not automatically a world-space straight-line family; do not insist every curved mesh edge must point to one fixed VP. Evaluate local tangent direction or patch-wise guide constraints.

Point/line cross products (`l=p\times v`) are valid for **straight projective** constructions; they are not a formula for fisheye curves.

### 2.4 Spherical and fisheye mapping — a defined, testable option

For a unit **camera-space** direction `d=(d_x,d_y,d_z)`, let

$$
\rho=\sqrt{d_x^2+d_y^2},\quad
\theta=\operatorname{atan2}(\rho,d_z),\quad
\varphi=\operatorname{atan2}(d_y,d_x).
$$

- `theta`: angle from forward (`+z`), radians, from `0` to `pi`.
- `phi`: azimuth around forward, radians.
- `f`: equidistant-fisheye radial scale in pixels per radian.
- `c=(c_x,c_y)`: image center in pixels.

**Equidistant fisheye** image coordinates:

$$
r=f\theta,\qquad
P_{\mathrm{fish}}(d)=
(c_x+r\cos\varphi,\ c_y+r\sin\varphi).
$$

At `rho=0`, pick a stable angular convention; the forward direction maps to the center regardless of `phi`. A front 180-degree field covers `theta\le pi/2`, image-disk radius `f*pi/2`. The antipode `-d` has `theta'=pi-theta` and azimuth opposite by `pi`; its image may be outside the front disk.

**Equirectangular full 360×180 spherical option** (separate output layout):

$$
\lambda=\operatorname{atan2}(d_x,d_z),\quad
\epsilon=\operatorname{atan2}(d_y,\sqrt{d_x^2+d_z^2})
$$
$$
x=c_x+W\lambda/(2\pi),\quad
y=c_y-H\epsilon/\pi.
$$

`lambda` is longitude; `epsilon` latitude; `W,H` are panorama pixel dimensions. Handle the ±pi horizontal seam by wrapping/splitting primitives. This layout is not interchangeable with a **single front fisheye disk**.

### 2.5 What 1, 2, 3, 4, 5, 6 and N mean — distinguish conventions

**Do not claim there is one universal mathematical "number-of-VP" projection switch.** Art-school 4/5/6-point styles are conventions for wide-angle coverage, while `N` can simply count distinct world-direction families. Use these explicitly identified demos:

| Demo | Model | Geometric demonstration / required visible guides |
|---|---|---|
| **1-point** | Rectilinear | One finite depth VP; remaining selected axis-family VPs at infinity (parallel lines) |
| **2-point** | Rectilinear | Two finite horizontal-direction VPs on a horizon/vanishing line (not necessarily screen horizontal); vertical family VP at infinity |
| **3-point** | Rectilinear | Three finite VP direction families; first two may determine one plane's vanishing line, the third is not required on that line; show connected box/folded-patch geometry, **not one homography** |
| **4-point (curvilinear convention)** | Explicit fisheye/spherical front view | A left/right antipodal rim pair and an up/down rim pair. Draw the **projected** curved guide families; do not choose arbitrary Bézier curves |
| **5-point (front 180° fisheye convention)** | Equidistant-fisheye front hemisphere | Four rim VPs (L/R, U/D) + center forward VP. Its opposite is **behind the observer** and **outside the front projection**, not implicitly infinity |
| **6-point (full spherical convention)** | Full spherical map (for example equirectangular) | All six directional poles of ±X, ±Y, ±Z, including the rear-facing partner of the center VP; map them with a correct 360° layout |
| **N independent directions** | Selected compatible projection | Choose `N` 3D direction families, project the corresponding VPs and all *their actual parallel-line guides*. Opposite families exist as directions; marker visibility depends on FOV. No arbitrary circle distribution |

For the conventional 4–6 demos, choose canonical orthogonal axes solely as **a reproducible example**; never impose orthogonality on arbitrary N direction-family subscriptions. The user may create many independent/non-Manhattan families.

### 2.6 Position, shape and depth are not fixed by VP markers alone

Guide directions/VPs constrain the orientations of projected lines, not the placement, size, and material shape of a particular UI surface. Also specify at least a **material anchor**, pose/size/relative depth or equivalent constraints, and for folds the **crease path and fold angle**, and for smooth bends a surface profile. Insufficient or contradictory inputs must produce an actionable diagnostic, not silently invented geometry.

## 3. Model architecture (proposed types; NOT current Qt built-ins)

Design mathematics as pure testable modules, separate from UI/event plumbing:

~~~text
PerspectiveScene / ProjectionSpace
  ProjectionModel (rectilinear | equidistantFisheye | equirectangular)
  CameraFrame + Viewport + visibility / clipping
  DirectionFamilyRegistry: N families, each with d and implicit -d
  VanishingPointProjection: projected markers + offscreen status
  ConstructionGuideEngine: actual world-space lines -> sampled screen curves
  GeometryConstraintSolver: per-surface/per-patch orientation & anchors
  MaterialSurface: single zero-thickness S(u,v,t)
  SurfaceRenderer: Qt Quick mesh / material, based on the same projected points
  InputInverseMapper: screen hit -> material (u,v) -> QML content coordinates
  Diagnostics: residuals, invalid geometry, projection / clipping / input status
~~~

**Proposed conceptual data contract**:

~~~js
scene = {
  projection: { model: "equidistantFisheye", fPixelsPerRadian: 280,
                center: {x:450,y:300}, fieldOfViewDegrees:180 },
  directionFamilies: [
    { id:"horizontal", direction3D:[1,0,0] },
    { id:"vertical",   direction3D:[0,1,0] },
    { id:"forward",    direction3D:[0,0,1] }
  ]
};
surface = {
  material: {width:280, height:120},
  anchor: {...}, pose: {...},
  subscriptions: [
    {familyId:"horizontal", regionId:"patchA", materialDirection:[1,0]},
    {familyId:"vertical",   regionId:"patchB", materialDirection:[0,1]}
  ],
  deformation: { mode:"crease", creaseU:0.55, foldAngleRadians:0.4 },
  transition: 1
};
~~~

`anchor` and `pose` need a concrete, documented type when implemented; the ellipses above are placeholders, **not runnable QML**. "Direction family" means a named group of **parallel 3D directions**, not screen X/Y or an arbitrary VP-count index.

**Interaction rules:**
- Adding/removing/repositioning visible VP markers never silently changes the projection model.
- Dragging a VP in a chosen projection should update the underlying direction through a defined inverse projection when possible, then recompute its opposite, guides, and dependent geometry. A manual screen-only VP override must be an explicitly labeled nonphysical/artistic mode.
- Restrict hard geometric consistency checks to **one planar patch**. A single UI sheet may consist of multiple C0-connected patches with different orientations; its whole-scene VP set need not be collinear.
- Preserve `PerspectiveMath.solve` for its existing single-planar-homography use; route cases outside its domain to the new solver, **not** to identity plus "unable to render".

## 4. Surface and transition model

Material coordinates `(u,v)∈[0,1]^2` stay fixed on **one original sheet**. Define a zero-thickness 3D embedding `S(u,v,t)∈R^3` with `t∈[0,1]`, then project:

$$
q(u,v,t)=P(S(u,v,t)).
$$

- **Flat mode**: at `t=0`, UI renders at its original undistorted screen rectangle. Define a consistent camera-space flat embedding or explicit identity-render path; verify pixel alignment.
- **Crease mode**: two or more adjacent parameter-domain patches share **identical 3D boundary positions** (C0); tangents on each side may differ (sharp fold). Do not generate thickness or extra faces. Material UVs are shared continuously.
- **Smooth mode**: continuous positions and intended tangent behavior; densify sampling adaptively where curvature requires it.
- **Transition**: `t=1` reaches the physically/construction-consistent target; intermediate frames must be finite and not self-intersect. A simple 2D interpolation `(1-phi(t))q0+phi(t)q1` is permissible for **visual transition**, but it does **not** necessarily preserve exact VP constraints at intermediate `t`; report this honestly. Physical fold animations should interpolate the sheet geometry before projection.
- **Corner** means a real discontinuity in surface orientation/crease at an interior locus when requested, not merely moving the four rectangle corners. Maintain distinction between `cornerTargets` (outer shape) and `creasePath/foldAngle` (interior orientation).

For a construction-consistent single planar patch, sample a 3D straight material-line family (e.g., `S(u0+sd_u,v0+sd_v)`) and compare it with its projected guide family. For creased/smooth surfaces, validate per patch or with local tangents; do not demand one VP for a curve whose 3D direction changes along its length.

## 5. Rendering and hit testing (Qt 6.5+)

Existing `ShaderEffectSource` + `ShaderEffect` + `GridMesh` may remain the **initial renderer** for a sheet texture. Qt `ShaderEffect.mesh` supports tessellated grids; current vertex shaders can be replaced/extended with projected mesh positions. Evaluate `QQuickItem::updatePaintNode`/`QSGGeometryNode` for dynamic topology, high-resolution curves/creases, and lower overhead only after correctness is proven.

Keep the original Button/TextField as **one live QML content tree**; a surface rendering must not create volume, duplicate interactive faces, or independently fake controls in Canvas.

**Critical limitation:** `ShaderEffectSource` draws into a texture but **does not automatically redirect mouse or keyboard events**. Inverse mapping and focus/IME/selection validation are mandatory later milestones, not guaranteed by render success.

For each projected mesh triangle, inverse-hit testing must identify its triangle in screen space, solve barycentric weights, and use the same weights on original material UVs. For a physically perspective-correct texture mapping, handle homogeneous/perspective-correct interpolation consistently. Reject degenerate triangles and define front/back/occlusion choices. Preserve click, hover, drag, text selection and keyboard focus behavior explicitly.

## 6. Execution milestones and stop/go gates

### M0 — Preserve baseline and define ground truth (first task)
- [ ] Read existing `README.md`, `PerspectiveMath.js`, `SurfaceGeometry.js`, QML demos and tests.
- [ ] Run existing Node/CTest and Qt build if environment supports them. Preserve `PerspectiveNVPApp` target.
- [ ] Write a **reference-geometry fixture**, not only screenshots: camera basis, projection, directions, guide origins, object/surface anchor, expected VP positions.
- [ ] Mark current prototype statuses accurately; no claim that 3-VP folded-surface support already exists.
- **Gate:** current tests continue to pass; new conventions (camera axes, units, image origin, FOV) are written down.

### M1 — Correct Projection + Pairing + Guide Construction (FIRST NEW IMPLEMENTATION)
- [ ] Implement/test pure projections: rectilinear, equidistant fisheye 180°, equirectangular 360°; visibility, clipping and seam behavior.
- [ ] Direction family with derived antipode; front/back visible status; rectilinear projective identification of ±d; points at infinity distinguished.
- [ ] Build guides by **projecting actual 3D parallel lines** (`a+s*d`). Curvilinear guides are sampled from projection, **not Bezier guesses**.
- [ ] Add inspectable guide/VP overlay, metadata on hover, and 1/2/3/4/5/6/N fixtures as in Section 2.5.
- [ ] Provide a **display toggle** for VP markers and guides without changing computed surface.
- **Gate:** numeric checks confirm each family and its visible endpoint(s), and screenshots exhibit coherent guides. **STOP HERE for review before M2.**

### M2 — Anchor + Intersection + Surface Alignment
- [ ] Define and validate anchor, pose, material direction, relative placement / scale / depth constraints.
- [ ] Construct a **single planar sheet** whose projected grid/edges match same-model guide lines.
- [ ] Do not reject non-collinear VP3 globally; permit a physically coherent connected multi-patch sheet if constraints demand distinct local planes.
- [ ] Render red diagnostics on the particular incompatible **patch** (or insufficient anchors), rather than rejecting the entire VP registry.
- **Gate:** measured distance from planar projected edge line to its specified finite VP near numerical tolerance, and verification against reference guide samples. For curvilinear, compare sampled curves/points rather than straight-line distance.

### M3 — Fold/Corner/Smooth Deformation
- [ ] Link existing corner and crease controls to **constructed** geometry, instead of separate screen-space targets only.
- [ ] C0 seam continuity; defined creased tangent discontinuity; smooth bend topology and sampling; no added volume.
- [ ] `transition=0` matches original QML pixels; `transition=1` matches target. Intermediate frames remain valid.
- **Gate:** error tolerances + screenshots at `t=0,0.25,0.5,0.75,1` and distorted surface grid from the same projection.

### M4 — Real QML interaction
- [ ] Implement transformed hit tests and input routing; explicit focus/IME policies.
- [ ] Test Button press/release, hover, drag and TextField cursor/selection/input under perspective and during transition.
- **Gate:** automated interactions at multiple screen-space points succeed on transformed controls.

### M5 — Visual quality + performance
- [ ] Compare direct-render vs texture-based edges and text; test antialiasing, mipmaps, resolution tradeoffs.
- [ ] Measure CPU/GPU time, draw calls, memory and dynamic VP movement at 1/10/50/100 sheets.
- **Gate:** benchmark report includes environment, backend, workload, p50/p95 frame times, and visual evidence.

## 7. Mathematical and visual tests (must be executable)

**Projection:**
1. Forward `(0,0,1)` -> fisheye center, rear `(0,0,-1)` -> outside front-hemisphere FOV.
2. `+X/-X` and `+Y/-Y` -> opposite front rim positions in the equidistant 180° example.
3. `d/-d` -> antipodes on the sphere; rectilinear same homogeneous VP for `d_z\ne0`, and infinity for `d_z=0`.
4. Inverse projection of any valid visible non-pole point returns original direction within tolerance.
5. 360° longitude seam handled without an incorrect line crossing the whole screen.

**Guides:**
6. Generate ≥2 *distinct* parallel world lines per family. Their curves are computed from `P(a+s*d)`.
7. In rectilinear, the projected lines intersect at finite VP, or are parallel when the VP is at infinity (within numeric tolerance).
8. In fisheye, projected guide endpoints approach the projected `±d` where visible; curve samples agree with direct projection.
9. VP movement changes direction and guide geometry consistently; opposite markers update as derived data.
10. N=8 with independent non-Manhattan direction families works **without arranging VPs on a decorative circle**.

**Surface:**
11. For the same projection, points on an aligned material edge lie on the projected construction guide (or sample curve).
12. 3 non-collinear finite VP world directions are **not incorrectly rejected at scene level**, though they cannot all belong to one planar homography.
13. Wrong/missing anchor constraints produce informative failures; no invented rectangle or zero-residual false-success.
14. Seam position continuity holds at all `t`; smooth and folded patches meet without gaps.
15. Reject invalid/self-overlapping cells, zero-divides, NaN/Inf, and unsupported FOV regions.

**Required screenshots:** labeled 1,2,3 rectilinear; 4,5 fisheye; 6 full spherical; N=8 world-direction families, all with source geometry + corresponding guide families. Output metadata lists projection, family directions, antipodal partner visibility and constraint errors. Images alone never count as pass unless numerical tests validate the same projection path.

## 8. Codex assignment and reporting format

**Codex: implement M0 and M1 only.** Do not start by editing the existing homography to remove the vanishing-line check; do not begin with corner/crease sliders; do not invent a GUI warp to make a visual "pass."

1. Read this plan and code in `prototype`; preserve current behavior.
2. Implement the projection / direction-pair / guide-curve mathematics in a pure module, with tests.
3. Add a Qt Quick demo overlay that uses those same projected guides, not separately interpolated lines.
4. Show at least 1,2,3,4,5,6,N fixture modes with displayed VP visibility and pairing status.
5. Build and run available unit tests and GUI screenshot tests; if the environment lacks GPU/window support, **state exactly what remains untested**.
6. Report each changed file, the precise formulas used, tests and results, screenshots/paths, observed edge cases and explicit limitations.
7. **Stop after M1** so geometry can be reviewed before any new surface renderer work.

## 9. References and provenance

- Current prototype repository: https://github.com/Wsesosse/Perspective-Alignment-for-QML-PAQ-/tree/prototype
- Qt 6 ShaderEffect: https://doc.qt.io/qt-6/qml-qtquick-shadereffect.html
- Qt 6 ShaderEffectSource (input is **not** redirected): https://doc.qt.io/qt-6/qml-qtquick-shadereffectsource.html
- Qt 6 QQuickItem Scene Graph custom nodes: https://doc.qt.io/qt-6/qquickitem.html
- Projective point/vanishing-line constraint is a property of a **single plane**, not the entire collection of world directions. The projection formulas above specify this implementation's coordinate conventions.
- 4/5/6-point drawing labels are **named illustration conventions**, not universal definitions of projection; note the selected projection beside every sample.

**Acceptance principle:** The rendered object and its guide system must be produced by one coherent geometrical model. VPs are not decorative markers, pairing is not an arbitrary link, and corner/crease distortion must follow defined surface constraints rather than a guessed warp.
