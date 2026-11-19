# PAQ — Implementation Plan V3
## End-user-configurable perspective alignment for QML / Quickshell

> **Status:** Proposed V3 architecture and execution plan; **not implemented** by creating this document.
>
> **Repository:** \`Wsesosse/Perspective-Alignment-for-QML-PAQ-\`, branch \`prototype\` (current default).
>
> **Basis:** Source inspected in November 2026: \`README.md\`, \`CMakeLists.txt\`, \`PerspectiveSceneController.qml\`, \`PerspectiveWorkbench.qml\`, \`PerspectiveGuideOverlay.qml\`, \`PerspectiveSurface.qml\`, \`SurfaceModelV2.js\`, \`ProjectionMath.js\`, \`DirectionFamilies.js\`, \`shaders/surface3d.vert\`, and existing tests. Preserve \`implementV2_Plan.md\` as the mathematical/rendering contract; this file supersedes its *product/workflow direction*, not its validated perspective theory.

---

## 0. Product decision: what PAQ is supposed to become

**PAQ = a user-configurable Perspective Alignment Framework for existing Qt Quick/QML UI.**

The intended operator is the **end user**, not just the QML developer. The developer registers eligible widgets and provides integration hooks. At app runtime, the user visually adjusts vanishing points and eligible widget layout, previews real perspective alignment, saves a **persistent configuration**, and later reloads it, including when the desktop wallpaper changes.

**Primary motivating use case:** rice **Caelestia Shell / Quickshell** so real desktop widgets visually align with architecture/environment in a wallpaper; one wallpaper or desktop-playlist entry may select a different saved PAQ profile. The framework must also work without Caelestia, and must not require PAQ to own or change the wallpaper itself.

### 0.1 User-approved conceptual roles

- **PAQ Toolbox:** **runtime visual editor**, logically and (as requested) as a QML child of the **UI Frame**. End user moves VP handles, chooses directions/surface controls, and edits permitted widget positioning. Editing must work without changing QML source code.
- **PAQ UI Frame:** **pre-alignment only** for its member widgets. It provides original, unwarped layout/positioning before perspective. Do **not** silently assign VP computation, folding, clipping, wallpaper switching, or general scene ownership to the Frame.
- **Members:** normal application-provided QML widgets registered with stable IDs, participating in PAQ's pre-alignment and alignment process. Membership does not imply all members are rendered as **one** texture/one physical sheet.
- **Surface / Perspective Engine:** takes pre-aligned material coordinates + explicit surface/VP constraints and calculates projected geometry.
- **Snapshot / profile:** user-authored configuration that can be saved, loaded, and selected by wallpaper. **Distinguish it from the existing \`scene.snapshot\` computed render data.**
- **Frame movement/size editing:** undecided user UX. Keep ability to extend later, but do **not** define movable/resizable frame as an unconditional requirement for V3 MVP.

### 0.2 What V3 must NOT quietly become

- Not a 3D game engine: no mandatory physics, lights, volumetric UI, scene-world editor, or side walls.
- Not automatic perspective detection from wallpaper images; manual alignment is the explicitly required workflow. Image-based suggestions may be researched separately, not advertised as delivered.
- Not a source-code-only editor for developers; saving arbitrary screenshots is not the required persistent format.
- Not a system requiring the end user to know 3D vector math just to move a visible VP.
- Not a replacement of working Qt/Quickshell window/input policies with invented global Wayland input injection.
- Not a requirement to select Qt Quick 3D as renderer. Keep backend choice independent of the authored profile and solve geometry once.
- Do not call a warped texture "interactive" until real QML Button/TextField interaction at the *displayed* position passes tests.

### 0.3 V3 end-to-end definition of done

1. An app (initially a demo; eventually Quickshell) supplies at least **Clock** and **Music** widgets as named PAQ members of a UI Frame.
2. End user activates the child PAQ Toolbox **while the app is running**; edits VP families and permitted pre-alignment; changes are reflected live and indicate invalid configurations.
3. User saves Profile A with stable IDs and an explicit wallpaper association.
4. Reopening the app (fresh process) loads Profile A and reconstructs visually equivalent layout and perspective **without** depending on previous in-memory IDs.
5. Switching to Wallpaper B selects Profile B, while returning to Wallpaper A restores Profile A; missing/corrupt profiles fail safely.
6. Both the projected controls **render and receive real pointer/keyboard input** at their warped locations at the final interaction gate.
7. The reusable PAQ module can be imported into a separate Qt Quick application and has an actually-tested Quickshell integration example.
8. 1/2/3/4/5/6/N labels are **presets/fixtures**, never limits on available direction families or assumptions about one surface's topology.

---

## 1. Current V2 source reality (do not misreport)

| Area | Existing code | Verified from source | Gap for V3 |
|---|---|---|---|
| Camera and projection | \`ProjectionMath.js\` | Rectilinear, equidistant fisheye, equirectangular, forward/inverse direction | Runtime configuration ownership; mapping to wallpaper render space |
| Direction families / antipodes | \`DirectionFamilies.js\`, \`PerspectiveSceneController.qml\` | Stores direction3D and derives opposite; N registry; VP drag | Stable authoring IDs, transactions, configurable save/load without preset replacement |
| True vs effective infinity | \`GuideConstruction.js\`, \`PerspectiveSceneController.qml\` | Separate exact/visual classifications, tolerances | Replace hardcoded 290×120 assessment region with per affected member/surface |
| Guides and handles | \`PerspectiveGuideOverlay.qml\` | Computed lines/curves, drag of visible finite VP markers | Reusable frame-child Toolbox, selections, editing mode and persistence |
| Surface geometry | \`SurfaceModelV2.js\` | Constructed sheet, limited two-panel crease | Hardcoded \`z=6\`, \`families[0..2]\`, \`presetKey==="2"/"3"\`, no general anchor/pose/patch constraints |
| QML visuals | \`PerspectiveSurface.qml\` | Live source QML tree and \`ShaderEffectSource\`, \`GridMesh\` shaders | Proper per-member/per-surface binding, inverse hit/input route |
| Quality | \`PerspectiveSurface.qml\` | Experimental \`renderScale: 5.0\`, mipmap, samples, smooth | No adaptive resource budget/profile |
| Tests | \`test_projection.js\`, \`test_guide_construction.js\`, \`test_surface_alignment.js\`, CTest | Math, sample alignment, some VP drag covered | No saved-profile, wallpaper-switch, member, or warped-input tests |
| Distribution | \`CMakeLists.txt\` | \`PerspectiveNVPApp\` standalone executable embedding a QML module | No installable/reusable PAQ library/module validated in another host |
| Persistence/wallpapers | No corresponding modules in source tree | **Not implemented** | Entire profile store, schema, bindings and host adapter |

**Keep backward compatibility:** \`PerspectiveMath.js\` single-plane solver, \`PerspectiveItem.qml\`, \`SurfaceDemo.qml\`, \`LegacyDemo.qml\`, \`PerspectiveWorkbench.qml\`, test fixtures and existing \`ShaderEffectSource\` path. The single-plane vanishing-line consistency check is legitimate; never disable it to make incompatible VP constraints "pass."

### 1.1 Technical debt that V3 must address early

- \`Component.onCompleted: applyPreset(presetKey)\` and \`onPresetKeyChanged: applyPreset(presetKey)\` can overwrite a user's explicitly authored directions when treating "N" as a preset. Loading user config must bypass this.
- Using array position rather than stable family IDs breaks persisted subscriptions under reorder/delete.
- The Surface's projection/validation and the Shader must remain consistent; do not make editing geometry an effect implemented *only* in a vertex shader while the CPU geometry, overlay and hit testing disagree.
- Geometry inspection currently depends on fixed reference-sheet dimensions. Real frame/member geometries must define those regions.
- This is **an architecture plan**, not evidence that any proposed file or new API exists.

---

## 2. Proposed V3 architecture and boundaries

\`\`\`text
Application / Quickshell (provides QML widgets + optional wallpaper events)
  |
  +-- PAQ UI Frame (pre-align member widgets in original 2D coordinates ONLY)
  |      +-- PAQ Member Registry (stable IDs; membership; original layout)
  |      +-- PAQ Toolbox [child of Frame; runtime edit UI; enabled on demand]
  |
  +-- PAQ Authoring Session / Controller (editable canonical state)
  |      +-- Camera + Projection + Direction Family Registry
  |      +-- Widget/Frame pre-layout state
  |      +-- Surface anchors, patches, subscriptions, fold constraints
  |      +-- edit / undo / preview / validate / save-or-cancel
  |      |
  |      +-- Geometry Solver --> versioned Derived Scene Snapshot
  |                            +--> VP markers / guides / diagnostics
  |                            +--> same projected surfaces + material UV
  |                            +--> inverse hit-test geometry
  |
  +-- PAQ Renderer & Input Adapter (actual Qt Quick controls)
  |
  +-- PAQ Profile Store (schema-validated, versioned, atomic disk writes)
         ^
         |
       Wallpaper Profile Resolver / host adapter
         (desktop playlist / Caelestia sends identity + rendered image mapping)
\`\`\`

**Core rule:** The Frame performs pre-alignment, the Toolbox edits authoring parameters, the Solver constructs geometry, the Renderer displays it, and the Store persists **authoring configuration**, not transient renderer state. Their ownership must remain separate even if some share a QML parent at runtime.

### 2.1 Proposed components / file responsibilities

Names are proposals; choose final naming once in the public API review, then keep it stable.

| Component | Purpose | Likely implementation |
|---|---|---|
| \`PaqFrame.qml\` | Logical/QML parent for eligible widgets and child Toolbox; pre-aligns registered members | QML \`Item\`, layout-safe |
| \`PaqMember.qml\` | Member wrapper with stable \`memberId\` and original content | QML Item; one original live QML subtree |
| \`PaqToolbox.qml\` | Runtime user editing controls; selects/moves visible VPs, member placement, preview and save/cancel | QML Qt Quick Controls |
| \`PaqAuthoringController\` | Single editable canonical configuration, mutation API, dirty/undo/validation | C++ QObject or carefully designed QML model |
| \`PaqSceneController\` | Projection/family computation and derived snapshot; evolves existing controller | Preserve pure \`ProjectionMath.js\` etc. |
| \`PaqSurfaceModel\` | Anchors/pose/patch/fold constraints and CPU geometry; replaces fixture-specific \`SurfaceModelV2.js\` behavior | Pure tested geometry + optional C++ |
| \`PaqSurfaceRenderer\` | Backend that draws same material UV and projected geometry | Current Qt Quick ShaderEffect first; backend swap later |
| \`PaqInputAdapter\` | Map transformed pointer to original item; maintain focus/grabs | Public Qt Quick interfaces; prove end to end |
| \`PaqProfileStore\` | JSON encoding, schema/version validation, migration, atomic save/load | C++ \`QStandardPaths\`, \`QSaveFile\`, JSON |
| \`PaqWallpaperProfileResolver\` | Resolve wallpaper/playlist identity to profile and map image coordinates to viewport | Host-driven QObject/QML API; **not** an image-detection engine |
| \`PaqQuickshellExample\` | Demonstrate import, panel window integration, input policy and wallpaper callbacks | Separate optional example/integration |

The Qt Quick 3D backend is **optional future research**. Do not add an engine dependency to the initial V3 module merely to support custom perspective.

### 2.2 Public design rules

- Stable string IDs for \`frameId\`, \`memberId\`, \`surfaceId\`, \`familyId\`, \`patchId\`, \`foldId\` and \`profileId\`; enforce uniqueness in their documented scope.
- Host/dev chooses which widgets register and which properties may be edited. User changes config, **not application source code**.
- All edits follow one path: \`user action -> canonical config -> validation -> derived geometry revision -> display + guides + hit-test\`.
- A preset is a factory that constructs an editable configuration; **no solver logic may depend on \`presetKey\`.**
- Read-only derived \`sceneSnapshot\` contains the current projection/visible guides/mesh/revision; persisted profiles must *not* contain \`QQuickItem\` pointers, shaders, transient geometry arrays or QML object IDs.
- Moving/deleting/reordering a member must not silently reassign another member's config. Missing member IDs are diagnosed; never bind by Repeater index.
- Restrict toolbox interaction to edit mode; when closed, handles do not intercept application UI clicks.
- \`PaqToolbox\` is a **child of \`PaqFrame\`** as the user's chosen conceptual structure. Its presentation layer may require an unclipped overlay/portal for off-frame handles, but must retain its frame ownership and not alter the frame's pre-alignment responsibility.
- No global mouse capture or privileged Wayland protocol use to bypass shell/window input boundaries.

---

## 3. The THREE geometry extensibility requirements

These are required for the long-term PAQ goal, but they should not block the **first** save/load user workflow. They belong in distinct later stages with strict tests.

### 3.1 Per-region VP subscription (stable-ID, material direction)

A material patch subscribes to **direction families** by ID and names the *material* direction \`[du,dv]\` to align. A VP is a projected world direction, not a destination automatically assigned to every UI vertex.

Example conceptual schema:

\`\`\`json
{
  "patchId": "left",
  "uvPolygon": [[0,0],[0.5,0],[0.5,1],[0,1]],
  "subscriptions": [
    {"familyId": "streetLeft", "materialDirection": [1,0], "weight": 1},
    {"familyId": "vertical", "materialDirection": [0,1], "weight": 1}
  ]
}
\`\`\`

- One planar patch requires a geometrically consistent orientation/placement; direction constraints alone are underdetermined without anchor/pose/scale.
- If multiple constraints on **one planar patch** conflict, mark that patch invalid with a quantified residual. Distinct connected patches can have distinct local orientations; do not globally reject non-collinear scene VPs.
- If a direction family disappears, retain a meaningful broken-reference diagnostic rather than guessing another family.

### 3.2 User-authored anchor, pose, material scale

\`anchor = { materialUV: [u,v], position3D:[x,y,z] }\` maps a named point on the original widget material into camera/world geometry. Provide explicit orientation/rotation and width/height or scale policy. Define handedness, units, camera basis (+X right,+Y down,+Z forward in current V2), and how screen transforms/local frame coordinate systems compose.

- \`PaqFrame\` pre-alignment defines the original 2D layout; \`anchor/pose\` define the constructed 3D surface **after** pre-alignment.
- If user drags a visible surface/anchor handle, its inverse mapping must specify what is held fixed (depth, plane, constraint) to avoid ambiguous "3D from one pixel" guesses.
- Keep \`transition=0\` pixel-aligned to the pre-aligned 2D source even as pose changes, and \`transition=1\` aligned to solved projection.
- Replace fixture-only \`z=6\` and fixed 290×120 source extents with explicit surface data. Preserve old fixture appearance via adapter-generated defaults where possible.

### 3.3 Arbitrary fold geometry (not only \`creaseU=0.55\`)

Allow named crease paths in normalized material \`(u,v)\` coordinates and a patch topology: start with a single straight crease, then multiple/diagonal line segments, then smooth bending.

- Surface remains a single **zero-thickness** material sheet per opted-in surface. No duplicate UI tree and no box sidewalls.
- Shared crease positions have **C0 continuity** (the same 3D point from each adjacent patch); a sharp fold may have different tangents, while smooth bends need appropriate tangent continuity.
- Define \`VP-driven\` versus \`fold-driven\` solving. If direction/anchor/fold angle are overconstrained, report the conflict and do not silently overwrite another authored constraint.
- Arbitrary folds require real mesh topology or adequate tessellation, shared UVs across seams, clipping rules and CPU-side inverse mapping. Existing two-panel \`GridMesh\` shader is a regression baseline, **not** a general arbitrary-topology solver.
- Geometry preview may show invalid diagnostic without corrupting the last committed saved profile.

---

## 4. Authoring data, derived snapshots, and persistent profiles

### 4.1 Three different objects — do not conflate them

1. **Authoring document / editable configuration:** canonical parameters: camera, family directions, member pre-layout, anchors, subscriptions, folds, wallpaper match and UI preferences. This is the source of truth.
2. **Derived runtime scene snapshot:** computed finite/infinite/antipodal VP data, guide samples, mesh, UVs, input hit-test structures, geometry revision. Rebuilt whenever authoring config/viewport changes; **never serialized as canonical geometry**.
3. **Saved PAQ profile:** validated/versioned serialization of the authoring document plus integration metadata. It is what desktop-playlist / a wallpaper event selects.

Do not store only raw screen VP positions. The finite guide coordinates depend on projection, camera intrinsics, viewport and wallpaper transform. Store canonical \`direction3D\`, explicit projection and camera values; preserve editable 2D anchor references separately if the user has attached them to wallpaper features.

### 4.2 Example version-1 JSON profile (illustrative contract)

\`\`\`json
{
  "schemaVersion": 1,
  "profileId": "city-night",
  "displayName": "City night alignment",
  "wallpaperBinding": {
    "provider": "desktop-playlist",
    "assetId": "wallpaper-city-01",
    "contentFingerprint": null,
    "renderMode": "cover"
  },
  "referenceViewport": {
    "logicalSize": [1920, 1080],
    "devicePixelRatio": 1,
    "monitorKey": "primary",
    "rescalePolicy": "preserve-wallpaper-registration"
  },
  "camera": {
    "projection": "rectilinear",
    "focalScale": 0.33,
    "tiltRadians": 0
  },
  "directionFamilies": [
    {
      "familyId": "streetLeft",
      "direction3D": [0.70710678, 0, 0.70710678]
    },
    {
      "familyId": "vertical",
      "direction3D": [0, 1, 0]
    }
  ],
  "frames": [
    {
      "frameId": "desktop-main",
      "viewportRectNorm": [0.05, 0.10, 0.90, 0.80],
      "members": [
        {
          "memberId": "clock",
          "layoutRectNorm": [0.06, 0.10, 0.30, 0.16]
        },
        {
          "memberId": "music",
          "layoutRectNorm": [0.48, 0.60, 0.44, 0.25]
        }
      ],
      "surfaces": [
        {
          "surfaceId": "clock-surface",
          "memberIds": ["clock"],
          "anchor": {
            "materialUV": [0.5, 0.5],
            "position3D": [0, 0, 6]
          },
          "orientationEulerRadians": [0, 0, 0],
          "materialSize": [2.0, 0.8],
          "patches": [
            {
              "patchId": "entire",
              "uvPolygon": [[0,0],[1,0],[1,1],[0,1]],
              "subscriptions": [
                {"familyId": "streetLeft", "materialDirection": [1, 0]}
              ]
            }
          ],
          "folds": []
        }
      ]
    }
  ],
  "editorPreferences": {
    "showGuides": true,
    "showVanishingPoints": true
  }
}
\`\`\`

**Important:** This is a **schema draft**, not a built-in/current API and not proof that this particular single-patch set of constraints determines unique geometry. The solver may require more independent constraints; provide validated defaults or report underconstraint. Final schema and units must be frozen and tested before compatibility guarantees.

### 4.3 Profile invariants

- Stable IDs, schema version, enum validation, nonzero finite unit directions (normalize on import), finite scalar values and bounded/validated counts.
- Missing member: other members still load; report orphan config and leave untouched app widget layout intact.
- Removed/renamed family: no silent subscription reinterpretation.
- Invalid/unsupported profile version: fail with an actionable error and preserve current valid scene.
- Save must be **atomic**, with exact error reporting. Preferred C++ implementation: \`QStandardPaths::AppConfigLocation\`, \`QSaveFile\`, Qt JSON APIs; no shelling out to commands or assuming arbitrary QML has cross-platform filesystem privileges.
- Loading is transaction-like: parse -> validate -> resolve IDs/viewport -> compute candidate -> atomically apply valid state. On failure keep existing scene/profile and do not leave an invisible UI.
- Define migration strategy for \`schemaVersion\` and produce round-trip deterministic output (order IDs explicitly where UI order matters).
- Prefer per-app namespaced directory and safe filename mapping from profile ID; do not trust wallpaper metadata as an arbitrary file path.
- Optional export/import may read a user-chosen file, but do not overwrite application configuration outside allowed paths by default.

### 4.4 Coordinate spaces and wallpaper correspondence

**Name every coordinate system:**

- Wallpaper **source-image pixels** and optional image normalized coordinates \`(x/I_w, y/I_h)\`.
- Wallpaper **displayed/cropped rectangle** in the target window/monitor.
- Window/viewport **logical pixels**, **physical pixels = logical × DPR**, and monitor identity.
- UI Frame local/pre-aligned **2D logical coordinates**.
- Member **material UV** in \`[0,1]^2\`.
- Solver **world/camera coordinates**.
- Derived VP position or infinity direction **in viewport projection coordinates**.

For common "cover" wallpaper rendering, mapping an image-normalized point \`q\` into the logical viewport \`(W,H)\` uses \`s=max(W/Iw,H/Ih)\`, \`ox=(W-s Iw)/2\`, \`oy=(H-s Ih)/2\` and \`p=(ox+s Iw qx, oy+s Ih qy)\`. Implement **the host's actual crop/scale/offset**; don't assume it uses cover if Caelestia or a wallpaper service actually uses another policy.

- **Finite/offscreen VP** is not automatically infinity. Exact projective infinity stays \`w=0\`; effective infinity is derived from angular and *physical*-pixel error over the actual affected surface/visible guide region.
- A wallpaper-feature annotation and a scene VP are **different concepts**. A direction outside the image can still be a valid VP. Support explicit coordinate-space tags for editable handles/references; don't force arbitrary VPs into \`[0,1]\` wallpaper image UV.
- Multi-monitor: a profile must specify monitor matching policy and optional per-monitor variations. "Primary" is only one possible binding; do not assume all displays share aspect ratio, DPR, viewport or wallpaper crop.
- When the viewport/crop changes, reproject from canonical directions and anchors, remap feature references, and show if registration residual exceeds tolerance. Do not promise visually identical placement across different wallpaper crops without measurement.

---

## 5. Runtime Toolbox (end-user UX, not a developer-only demo)

### 5.1 Required editing session

\`\`\`text
Application running
  -> enter EDIT mode for a PAQ Frame
  -> show PAQ Toolbox (child of Frame) and geometry overlay
  -> select registered member / surface / VP family
  -> drag a visible VP or adjust an offscreen/infinite direction with an
     appropriate angular/directional control
  -> preview projected member(s), guide curves and validity
  -> optionally edit member pre-alignment in Frame-local coordinates
  -> Save Profile / Save As / Revert / Cancel
  -> return to VIEW mode; hidden toolbox does not steal UI input
\`\`\`

- Visible finite handles use projection inverse to update the **canonical direction**; partner direction \`-d\` updates automatically.
- For mathematical infinity, display **direction** editor/arrow rather than a fabricated distant pixel coordinate; do not use arbitrary \`1e9\` as infinity.
- For fisheye/panoramic projection, partner visibility/FOV and seam handling remain derived from the same projection.
- Editing guide visibility must not change projected geometry. Guides must not be decorative Beziers.
- Toolbox should expose selected family, coordinates/status, effective vs true infinity, active frame/member, geometry diagnostic, dirty indicator, Save/Cancel and a way to restore the last valid configuration.
- Workbench should be refactored to reuse the runtime Toolbox/overlay components, rather than shipping **two separate editors** with diverging algorithms.
- A user should not have to open \`PerspectiveWorkbench.qml\` or use a preset just to save a wallpaper-specific layout.

### 5.2 Authoring transactions

- \`beginEdit(frameId)\`, \`applyEdit(command)\`, \`validate()\`, \`save(profileId)\`, \`cancelEdit()\` are **proposed interfaces**, not implemented methods.
- Keep \`committedConfig\` and \`workingConfig\` separate; edits are live previews but do not autosave unless the user explicitly enabled that policy.
- Use immutable-style changes or QObject signals so moving a handle increments a single meaningful geometry revision. Avoid direct mutation of nested JS objects that fails to notify QML bindings.
- Support undo/redo for at least one complete pointer drag as one logical edit (optional for first vertical slice but required for full Toolbox).
- Deletion of a direction family with subscribers needs explicit policy (reject, unlink with diagnostic or user-confirmed cascade).
- Closing Toolbox without saving prompts/reverts according to a documented policy; do not silently corrupt the saved wallpaper profile.

### 5.3 UI Frame: intentionally narrow responsibility

- Own a stable \`frameId\` and a registry of members; compute **pre-aligned 2D local rectangles** for the original QML content.
- Member register/unregister must not destroy unrelated widgets. Registry should expose \`memberId\`, original bounds, chosen edit permissions and associated surface ID.
- User-adjusted pre-alignment is an **authoring property** stored in profile, but the Frame itself does not choose VPs, deform meshes, infer wallpaper features, or implement a camera.
- Frame coordinate mapping should be explicit when its Qt parent has existing transforms/anchors; avoid double-applying layout in the Shader.
- Avoid forcing unrelated members into a single texture. Multiple member surfaces can share **one scene/camera** and individual saved constraints.
- QML Toolbox remains the Frame's child. Handle visibility and clipping policy must work when finite VPs lie outside the Frame content rectangle without interfering with other desktop applications/windows.
- The exact user UX for moving/resizing the **Frame itself** remains open; don't gate initial V3 on a design not chosen yet.

---

## 6. Renderer, actual input and performance boundaries

### 6.1 Single source of geometric truth

- One solved surface record: \`(materialUV, worldPosition, projectedPosition, patchId, triangleIndices, revision)\`; adjacency/crease metadata as needed.
- The same revision feeds guide visualization, rendered geometry and inverse-hit mapping.
- Keep source QML controls live; do not replace them with painted fake Button/TextField rectangles.
- Initial renderer can stay on \`ShaderEffectSource\`/Qt Quick \`ShaderEffect\`. The model must become CPU-visible or otherwise yield equivalent CPU hit-test geometry; pure Shader-only world geometry is not enough.
- The current planar and two-panel shader implementations can remain compatibility paths. Additional arbitrary topology must not be faked by mutating just four corner targets.
- Track texture resolution scaling explicitly; current 5x texture per axis means ~25x base source pixels before other render buffers. Quality presets and resource cap come **later**, after functional correctness.

### 6.2 Interaction is a release gate, not optional polish

- Warp mouse/touch scene coordinate -> appropriate projected visible triangle -> perspective-correct UV -> original child coordinate.
- Preserve pointer grabs, hover, release, click counts, dragging, focus, keyboard input, TextField caret, selection and IME. Must test at \`transition=0,0.5,1\`.
- Qt Quick \`ShaderEffectSource\` by itself does not automatically remap input. Do not claim generic widget support from an overlaid \`MouseArea\` that manually fires a Button signal.
- Edit-mode handle grabs and view-mode widget grabs must be mutually well-defined. A toolbar must not intercept content interaction when hidden.
- If full Qt Quick input redirection cannot be proven on the chosen backend, mark the limitation explicitly and explore a Qt-provided interactive surface path or alternative adapter. Do **not** let persistence completion be labeled full PAQ readiness.

### 6.3 Wallpaper/Quickshell integration boundaries

- Adapter receives \`wallpaper identity\`, \`rendered image transform\`, \`monitor/window identity\` and \`profile change\` events from the host. No mandatory Spotify, playlist, Caelestia-specific object or global wallpaper service dependency inside PAQ Core.
- If app provides no wallpaper integration, user can manually switch profiles: framework must still work.
- Use real Quickshell/Caelestia host code only after inspecting its current API and Qt runtime; do not assume \`View3D\`, shader effects, transparent panel hit regions or window-resource sharing work in that host without a test.
- Host owns Wayland layer-shell window/input region policy. PAQ consumes only input already legitimately delivered to its window.
- Test wallpaper A -> B -> A and change of resolution, scaling, monitor, crop policy and absent profile.
- Avoid blocking rendering during profile I/O or GPU-heavy texture rebuilds; prepare validated config then apply a coherent scene revision.

---

## 7. Implementation milestones, deliverables and stop/go gates

### V3.0 — Freeze baseline and separate product state (FIRST)

**Tasks**
- [ ] Run/build existing Qt/CMake/Node/CTest and record actual versions/results; do not merely copy README's earlier verification statement.
- [ ] Add a machine-readable state-contract draft and document source-vs-derived properties.
- [ ] Ensure the existing V2 Workbench/SurfaceDemo/LegacyDemo continue working.
- [ ] Refactor \`PerspectiveSceneController\` so \`loadPreset(key)\` explicitly *creates authoring config*; \`loadConfiguration(config)\` applies custom config **without any implicit preset reset**. Remove \`presetKey\`-specific solver behavior from the new code path, retaining a compatibility adapter where needed.
- [ ] Introduce stable family IDs; verify add/remove/reorder and state notifications.

**Gate:** Custom families survive scene recreation; no QML \`Component.onCompleted\` preset overwrite; old numeric tests unchanged.

### V3.1 — Persistent authoring profile FIRST VERTICAL SLICE

**Tasks**
- [ ] Freeze JSON v1 schema, units and migration/version policy; implement validator and serialization.
- [ ] Implement \`PaqProfileStore\` with atomic save, load, list, delete (with confirmation in UI), import/export APIs and error messages.
- [ ] Roundtrip exact canonical direction families, projection, camera, editor choices and a basic frame/member layout stub. No attempt to store GPU pixels or \`scene.snapshot\` guides.
- [ ] Demonstrate Save/Load from a **fresh application process** and no regression for 1/2/3/4/5/6/N presets.

**Gate:** Edit VP -> save -> terminate process -> reopen -> load -> equivalent projected VP/guide geometry (documented tolerance); bad/unknown-schema file does not replace the current valid scene.

### V3.2 — UI Frame + member registration / pre-alignment

**Tasks**
- [ ] Implement \`PaqFrame\` (pre-alignment only), \`PaqMember\` stable registry and original QML subtree ownership.
- [ ] Register at least two real Qt Quick controls/widgets with independent IDs/surfaces (Clock and Music placeholders are acceptable as actual QML components).
- [ ] Support editing and persisting local pre-alignment rectangles while maintaining the native QML source tree.
- [ ] Verify frame resizing, initial layout, reparent/resize safety and missing/duplicate IDs; do not require every member to share a single sheet.
- [ ] Attach the Toolbox **as a Frame child** in the component tree, initially with basic selection and edit-state UI.

**Gate:** Move member in Frame -> save -> reload -> member returns to pre-aligned rectangle; other members are unaffected. With \`transition=0\`, pixels match the pre-aligned unwarped layout.

### V3.3 — PAQ Toolbox: end-user visual editing

**Tasks**
- [ ] Extract reusable VP/guide overlay and UI controls from \`PerspectiveWorkbench.qml\` into \`PaqToolbox.qml\` without duplicating math.
- [ ] Edit finite VPs, infinity directions, projection/family count, select member/surface; show live diagnostics and dirty state.
- [ ] Begin/preview/save/cancel working/committed config; handle at least Save As and Reset; add undo/redo when stability proven.
- [ ] Guide/VP overlays can be hidden independently; no accidental "overlay-only" fake alignment.
- [ ] Finish a complete in-app user flow with **no editing of QML source**.

**Gate:** User can visually author and restore two distinct profiles for the same registered widget set; edit handles are unavailable in view mode.

### V3.4 — Wallpaper / Desktop Playlist profile binding

**Tasks**
- [ ] Add host-agnostic wallpaper identity + render transform + viewport mapping adapter.
- [ ] Associate Profile A and Profile B with distinct wallpaper asset keys. Provide manual selection fallback.
- [ ] On wallpaper change choose the saved profile; parse/validate/apply atomically. Define no-match/failure policy.
- [ ] Implement cover/contain/crop coordinate mapping against *actual host transform* and per-monitor DPR.
- [ ] Persist associations; do not store opaque absolute paths as sole identity if a host provides stable IDs; optionally use content fingerprint to detect renamed images.

**Gate:** A -> B -> A restores distinct VP, frame/member layout and projection; resize/crop test produces a reported mapping status rather than silent incorrect placement.

### V3.5 — General surface alignment/geometry API

**Tasks**
- [ ] Replace \`SurfaceModelV2.js\` fixture-based families[0..2]/preset-special-casing with stable-ID patch subscriptions.
- [ ] Add explicit anchor, pose, scale and per-surface evaluation region.
- [ ] Implement arbitrary number of compatible planar patches and continuity at shared boundaries; reject inconsistent constraints with local residual.
- [ ] Add first generic straight crease path, then diagonal/multiple crease topology. Keep UI zero-thickness and shared source UVs.
- [ ] Later add smooth bends and a distinct continuity model; do not label triangulated C0 approximation "smooth" without tangent tests.
- [ ] Maintain mathematically consistent finite/infinity and rectilinear/fisheye/panoramic behavior.

**Gate:** Two or more unrelated patch subscriptions/anchors/folds can be edited and saved without reference to a preset key; same projection drives guides and sheet; check continuity, curvature where applicable and target alignment.

### V3.6 — Real warped Qt Quick input (REQUIRED before claiming user-ready)

**Tasks**
- [ ] Produce CPU-side or validated-equivalent mesh/UV inverse mapping that exactly matches renderer revision.
- [ ] Implement pointer routing with Qt public APIs and test a real Button and TextField (not manual signal invocation).
- [ ] Test transformed hover, press/release, drag, text focus, caret, selection, IME, clipping, occlusion and scene changes mid-grab.
- [ ] Distinguish edit-mode handle input from view-mode application control input; no ghost clicks in original positions.

**Gate:** All supported native control interactions occur at their displayed warped position; tests fail if interaction only works at original location. If not passed, mark remaining mode \`visual-only\`.

### V3.7 — Reusable module + Quickshell validation + quality

**Tasks**
- [ ] Extract installable QML module/library (choose stable URI, e.g. \`PAQ\`); keep \`PerspectiveNVPApp\` as consumer/demo, not the only host.
- [ ] Validate a separate minimal Qt Quick app imports the module without copying internal files; include install/deploy instructions.
- [ ] Add optional Quickshell/Caelestia host example using *current inspected interfaces*; verify actual panel input region, transparency, scaling and multiple windows.
- [ ] Profile geometry rebuild / VRAM / texture scale; replace hardcoded 5x render scale with documented quality policy, budgets and degradation diagnostics.
- [ ] Document stable QML API, user edit tutorial, profile storage/migration and limitations. Maintain automatic regression tests.

**Gate:** Independent application imports module; demonstrable host integration and end-to-end A/B wallpaper workflow; no regressions at 1/2/3/4/5/6/N, and acceptable interaction/quality benchmark results.

---

## 8. Verification plan: executable fixtures, not appearance-only claims

### 8.1 Source-level/unit tests

Suggested additions (names not existing yet):
- \`test_v3_authoring_state.js\`: load custom config, preset reload explicit, family ID reorder/delete, geometry revision.
- \`test_v3_profile_schema.js\`: serialize/deserialize, deterministic JSON, versions, malformed values, dangling references.
- \`test_v3_frame_layout.js\`: frame/member rect mapping, origin, transform, resize.
- \`test_v3_wallpaper_mapping.js\`: exact contain/cover mapping, DPR, crop offsets, per-monitor viewport, offscreen VP unaffected by accidental pixel clipping.
- \`test_v3_patch_constraints.js\`: per-patch family ID, incompatible local constraints, anchor/pose, continuity.
- \`test_v3_fold_topology.js\`: one/diagonal/multiple folds, shared vertices/UV, tangent behavior, invalid cell detection.

### 8.2 Qt integration tests

- [ ] Drag VP through Toolbox (child of Frame), witness same revision change in guide and surface.
- [ ] Real Qt Quick Button/TextField loaded as \`PaqMember\` descendants.
- [ ] Run 1×/2× DPR, viewport resize and wallpaper crop variations without broken coordinate mapping.
- [ ] Full save/load **new process**, not just "Save then load while same model is alive."
- [ ] Simulated wallpaper events A/B/A with stable host-provided identity.
- [ ] Projected controls receive actual pointer/focus/IME interaction after V3.6.
- [ ] No visual/input regressions in V2 demos and V2 numerical fixtures.
- [ ] Qt 6.5+ compatibility or explicitly declare a newer baseline after verifying used APIs; don't implicitly rely on Qt 6.7-only types.

### 8.3 Exact observable MVP proof

\`\`\`text
(1) Start demo with Wallpaper A + Clock/Music in one PAQ Frame.
(2) Open child Toolbox; move VP1 + one member's pre-layout.
(3) Save profile "A". Quit app completely.
(4) Restart; load A. Verify numeric directions/rectangles + screenshot.
(5) Switch wallpaper B; save different alignment as "B".
(6) Switch A -> B -> A; assert same Profile IDs and recomputed geometry.
(7) Close Toolbox; verify no editing overlay intercepts normal app input.
(8) After V3.6, click and type only at visually projected coordinates.
\`\`\`

Capture both **source parameters and geometric residuals**. A screenshot alone is not a proof of perspective constraints or QML interaction.

---

## 9. Scope/decision register: do not invent unanswered product details

| Decision | Current direction | Status |
|---|---|---|
| Toolbox ownership | Runtime child of UI Frame | User-defined |
| Frame responsibility | **Pre-alignment only** | User-defined |
| Frame reposition/resize UX | Possible later, not required initial functionality | **Not finalized** |
| One frame vs per-widget sheet | A frame can contain multiple registered members and independent surfaces; exact UX policy TBD | Proposed |
| End-user edit permissions | Host declares editable fields; user adjusts runtime | Proposed |
| Save format | Versioned canonical JSON profile | Proposed |
| Wallpaper identity | Host adapter supplies stable wallpaper/playlist identity; PAQ stores association | Proposed |
| Camera control UI | User moves VP visually; expert controls may expose numeric values | Proposed |
| Per-region VP / anchor / folds | Required long-term, progressively implemented | User goal + proposed contract |
| Backend | Decouple from Solver; Qt Quick existing path first | Proposed |
| Input adapter | Must genuinely route native controls | Required release gate |
| Automatic wallpaper perspective inference | Not part of user-stated MVP | Excluded |
| Persistence paths / external integration | Host-aware, versioned, safe files; Quickshell adapter only after test | Proposed |

**Avoid expanding the UI Frame's responsibilities while the user has expressly limited it to pre-alignment.** If an implementation needs ownership of a scene/profile, put it in controller/session/store, not Frame.

---

## 10. Immediate Codex assignment — ONLY V3.0 then V3.1

> **Do not implement the entire plan at once.** Begin by changing the smallest safe layer that makes end-user-authored configurations first-class. No new fake 3D shapes, no replacement of Qt controls, no custom input claims.

1. Inspect the exact \`prototype\` branch again and run existing tests/build before editing. Note failures and environment details.
2. Make preset loading explicit and create a canonical editable configuration type. Decouple \`presetKey\` from \`SurfaceModelV2.js\` via a compatibility adapter so existing demo appearance is preserved.
3. Implement stable string IDs for direction families, and a \`loadConfiguration\` path that does not trigger default \`Component.onCompleted\` preset reset. Test custom configs and reorder.
4. Design/document **schemaVersion 1** with validation rules and migration policy; implement profile persistence and a small demo Save/Load UI using supported Qt C++ disk APIs.
5. Add automated save/restart/load and malformed-config tests; retain all V2 tests.
6. Produce a completion report containing: files changed, exact CLI commands and results, observable demo workflow, limitations, and branch/commit. Stop for review **before** Frame/Toolbox/Wallpaper features.

**First release candidate of V3 is not a 5-point demo:** it is a reliably restored user-authored scene with stable IDs and a real, versioned profile. Full V3 completion still requires runtime Frame/Toolbox, wallpaper binding, general solver and input routing.

---

## 11. Baseline references

- Existing V2 plan: \`implementV2_Plan.md\` (projection math, antipodes, infinity, guide curves, geometry/input correctness)
- Current implementation: \`ProjectionMath.js\`, \`DirectionFamilies.js\`, \`GuideConstruction.js\`, \`PerspectiveSceneController.qml\`, \`SurfaceModelV2.js\`, \`PerspectiveSurface.qml\`, \`PerspectiveGuideOverlay.qml\`
- Existing UI: \`PerspectiveWorkbench.qml\`, \`SurfaceDemo.qml\`, \`LegacyDemo.qml\`
- Existing tests: \`test_projection.js\`, \`test_guide_construction.js\`, \`test_surface_alignment.js\`, \`test_solver.js\`, \`test_surface_geometry.js\`
- Qt Quick source rendering/picking limitations from V2 plan; Qt APIs should be rechecked before choosing an input-routing implementation.
