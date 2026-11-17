# Perspective Surface (Qt 6.5+)

One zero-thickness QML control sheet, with a separate legacy planar N-VP demo.
The current surface renderer supports exact compatible planar VP projection
and **2D screen warps** for corner/crease modes. A 3D embedding and common
camera are permitted by the design but are not implemented yet.

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

The default screen demonstrates live planar VP subscriptions. Drag VP markers,
select 1–4 constraints, or switch to corner/crease and drag target handles.
The transition slider moves from 0 (flat) to 1 (target). The "Legacy VP demo"
button opens the preserved original planar prototype.

## Surface API

```qml
PerspectiveSurface {
    width: 440
    height: 230
    mode: "planar"                 // "planar", "corner" or "crease"
    projectionMode: "screenWarp"   // only implemented projection mode
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
Corner interpolation is bilinear and is not claimed to be a homography or exact
3D perspective.

## Tests

```bash
node test_solver.js
node test_surface_geometry.js
ctest --test-dir build --output-on-failure
```

The geometry tests cover identity, target corners, seam continuity, crease
kink and invalid targets. The legacy planar solver tests cover 1–8 compatible
subscriptions and incompatible cases.

For a native graphics screenshot:

```bash
PERSPECTIVE_SCREENSHOT=/tmp/perspective-vp.png ./build/PerspectiveNVPApp
PERSPECTIVE_TEST_TRANSITION=0 PERSPECTIVE_SCREENSHOT=/tmp/perspective-flat.png ./build/PerspectiveNVPApp
PERSPECTIVE_TEST_VP3_Y_OFFSET=30 PERSPECTIVE_SCREENSHOT=/tmp/perspective-invalid-vp.png ./build/PerspectiveNVPApp
```

## Proven status and limits

- Milestones 0 and 1: clean build, Node tests and native Qt rendering verified.
  Corner and crease modes render the same real `Button` and `TextField`
  source. Flat and target screenshots were inspected on the local Wayland
  backend.
- Planar VP mode is connected to `PerspectiveSurface`; the default demo
  renders a 4-VP compatible fixture, with draggable markers and diagnostics.
- Warped visuals do **not** remap pointer input. A Button may receive clicks
  only at its original, undeformed coordinates. Text caret, selection, focus
  and IME behavior are not validated for the warp.
- Smooth curved mode, a 3D sheet/camera, per-region folded-sheet N-VP subscriptions,
  warped input mapping and performance benchmarks are later milestones.
- The legacy `PerspectiveItem.qml` still uses one homography. It supports
  compatible N direction-to-VP subscriptions with diagnostics; it does not
  model a folded sheet or non-collinear 3-VP configuration on one plane.
