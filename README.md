# STILL IN PROTOTYPE
# Perspective Surface (Qt 6.5+)

One zero-thickness QML control sheet, with V2 construction workbench and
separate earlier surface/planar demos. The V2 workbench now projects a
constructed 3D sheet through the same camera used by its VP guides. The
earlier demos retain their planar VP solver and 2D screen warps.

## Build and run

```bash
cmake -S . -B build -G Ninja
cmake --build build
./build/PerspectiveNVPApp
```

Requires Qt 6.5+ Quick, QuickControls2 and ShaderTools. The executable is
`PerspectiveNVPApp`; the QML module remains `PerspectiveNVP`.
Use a graphics backend that supports `ShaderEffect`. Qt Quick's software
backend does not render the warp.

Default screen opens **V2 construction workbench**. Select rectilinear,
equidistant fisheye or equirectangular projection, then 1/2/3/4/5/6/N preset.
Drag finite VP handles to change underlying 3D direction; opposite direction
and projected world-line guides update. Toggle guides/VPs independently.
Top-right button cycles to earlier Surface demo and Legacy demo.

The workbench's real Button/TextField render on the projected sheet. Presets
2 and 3 start with a continuous two-panel corner fold; the Sheet selector can
flatten it. Transition 0 shows the flat source; transition 1 shows the
constructed target. Dragging a VP handle updates both guides and sheet.
Warped pointer input remains pending, so these controls are visual-only at
their displayed coordinates.

## V2 geometry and surface

Pure modules: `ProjectionMath.js`, `DirectionFamilies.js`,
`GuideConstruction.js`, `ProjectionFixtures.js`. Reference fixture:
`fixtures/reference_geometry.json`. Camera axes are +X right, +Y down,
+Z forward; image origin is top-left. Rectilinear uses
`(cx+fx·x/z, cy+fy·y/z)`. Fisheye uses `r=f·atan2(√(x²+y²),z)`.
Equirectangular uses longitude/latitude with screen Y increasing downward.
3-point preset tilts camera and retains the same world direction families as
2-point preset.

Every guide samples actual world lines `a+s·d` through the selected projection.
Each family stores normalized `d`; partner `−d` is derived. Rectilinear
`±d` share one homogeneous VP. A VP with `w=0` is mathematical infinity
and renders as an arrow. Finite offscreen VPs remain finite. Effective
infinity is a display diagnostic using guide angular spread and endpoint
deviation in physical pixels over the 290×120 reference-sheet region;
it never changes underlying VP or solver.
Angular projections instead report visible curve tangent spread and maximum
deviation from each sampled curve's endpoint chord. Straight-looking curves
retain their real antipodal metadata.

`SurfaceModelV2.js` constructs the sheet from the same scene snapshot as the
guides. `shaders/surface3d.vert` projects its two material patches and samples
one QML source texture. For the 2/3-point fixtures, the patches meet on one
3D crease. Presets 1–6/N use the selected projection. The rectilinear
diagnostic reports sampled target line/VP residual. Geometry validity checks
sampled cell orientation and camera visibility. M2 alignment and the initial
crease portion of M3 are implemented; arbitrary surface construction, smooth
bends and M4 input mapping remain pending.

## Surface API

```qml
PerspectiveSurface {
    width: 440
    height: 230
    mode: "planar"                 // "planar", "corner" or "crease"
    projectionMode: "screenWarp"   // or "surface3d" with sceneSnapshot
    transition: 1                  // 0..1, eased with smoothstep
    creaseU: 0.55                  // material coordinate, 0..1 exclusive
    meshColumns: 16
    meshRows: 8
    cornerTargets: [
        Qt.point(10,20), Qt.point(415,8),
        Qt.point(20,213), Qt.point(410,225)
    ]
    seamTargets: [Qt.point(250,45), Qt.point(205,205)]
    subscriptions: [
        {vp: vpOne, direction: Qt.point(1,0), region: "all"},
        {vp: vpTwo, direction: Qt.point(0,1), region: "all"}
    ]
    Button { text: "Real QML Button" }
}
```

`cornerTargets` order: top-left, top-right, bottom-left, bottom-right.
`seamTargets` are the top and bottom endpoints of the target crease. In
`corner` mode, the seam is derived from the single bilinear patch. In
`crease` mode, left and right bilinear patches share those endpoints and the
whole seam; their tangents can differ. Two shader meshes sample disjoint U
regions of **one** `ShaderEffectSource` texture made from the original QML
content. No thickness, side wall, back surface or duplicate content face is
created.

In `planar` mode, subscriptions use the existing exact direction-to-VP
homography solver, now rendered through the same texture source. VP coordinates
are mapped with `mapFromItem`, so marker and sheet need not share a parent.
`maxVpError` reports the target solver residual. All planar subscriptions
must use `region: "all"` and `weight: 1` (the default); incompatible or
non-collinear constraints are
rejected with a visible diagnostic. A planar sheet cannot realize three
non-collinear VP direction families. At intermediate transition values the
homography interpolates from identity, so the target VPs apply exactly at
`transition: 1` within the solver's 1.5 px tolerance, not throughout the
transition. The displayed residual reports actual VP error.

`geometryValid`, `diagnostic`, and `invertedTriangleCount` report invalid
parameters or degenerate/inverted sampled cells. Invalid geometry is not drawn.
Corner interpolation in `screenWarp` mode is bilinear and is not claimed to
be a homography or exact 3D perspective. `surface3d` mode uses the constructed
3D sheet; intermediate transitions interpolate projected screen positions.

## Tests

```bash
node test_solver.js
node test_surface_geometry.js
node test_projection.js
node test_guide_construction.js
node test_surface_alignment.js
ctest --test-dir build --output-on-failure
```

The geometry tests cover identity, target corners, seam continuity, crease
kink and invalid targets. The legacy planar solver tests cover 1–8 compatible
subscriptions and incompatible cases.
Projection tests cover camera tilt, projection inverse, antipodes, 1–6/N
fixtures, true/far infinity and front/rear visibility. Guide tests cover
projected parallel lines, fisheye endpoints, spherical seam splitting,
effective-infinity thresholds, curve straightness and DPR. Surface alignment
tests cover 1–6/N fixtures, flat and target positions, seam continuity,
orientation and sampled guide residual. If Qt Test is installed, CTest also
drags a real workbench VP handle and verifies that both scene and surface
geometry revisions change.

For a native graphics screenshot:

```bash
PERSPECTIVE_TEST_PRESET=3 PERSPECTIVE_SCREENSHOT=/tmp/paq-3.png ./build/PerspectiveNVPApp
PERSPECTIVE_TEST_PRESET=5 PERSPECTIVE_SCREENSHOT=/tmp/paq-5.png ./build/PerspectiveNVPApp
PERSPECTIVE_TEST_PRESET=N PERSPECTIVE_SCREENSHOT=/tmp/paq-N.png ./build/PerspectiveNVPApp
PERSPECTIVE_TEST_PRESET=3 PERSPECTIVE_TEST_TRANSITION=0.5 PERSPECTIVE_SCREENSHOT=/tmp/paq-fold.png ./build/PerspectiveNVPApp
```

## Proven status and limits

- V2 M0/M1 plus M2 alignment and initial M3 crease: clean build, numeric
  tests, native Qt workbench rendering and automated handle drag verified.
  Preset screenshots captured, including flat, intermediate and target frames.
- Earlier surface prototype milestones 0 and 1: clean build and tests verified.
  Corner and crease modes render the same real `Button` and `TextField`
  source. Flat and target screenshots were inspected on the local Wayland
  backend.
- Planar VP mode is connected to `PerspectiveSurface`; the default demo
  renders a 4-VP compatible fixture, with draggable markers and diagnostics.
- Warped visuals do **not** remap pointer input. A Button may receive clicks
  only at its original, undeformed coordinates. Text caret, selection, focus
  and IME behavior are not validated for the warp.
- Smooth curved mode, arbitrary anchor/pose controls, per-region folded-sheet
  N-VP subscriptions, warped input mapping and performance benchmarks remain.
- The legacy `PerspectiveItem.qml` still uses one homography. It supports
  compatible N direction-to-VP subscriptions with diagnostics; it does not
  model a folded sheet or non-collinear 3-VP configuration on one plane.
