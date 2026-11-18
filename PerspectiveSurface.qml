import QtQuick
import "SurfaceGeometry.js" as Geometry
import "PerspectiveMath.js" as PerspectiveMath
import "ProjectionMath.js" as Projection
import "SurfaceModelV2.js" as SurfaceModelV2

Item {
    id: surface
    objectName: "surface"
    default property alias content: sourceContent.data

    property real transition: 0
    property string mode: "corner"             // planar | corner | crease
    property string projectionMode: "screenWarp" // screenWarp | surface3d
    property var sceneSnapshot: null             // V2 scene, parent coordinates = viewport
    property int meshColumns: 16
    property int meshRows: 8
    property real creaseU: 0.55
    property var cornerTargets: [
        Qt.point(0, 0), Qt.point(width, 0),
        Qt.point(0, height), Qt.point(width, height)
    ]
    property var seamTargets: [
        Qt.point(width * creaseU, 0),
        Qt.point(width * creaseU, height)
    ]
    property bool showGrid: false
    readonly property bool inputMappingReady: false
    property var subscriptions: [] // {vp, direction, region:"all", weight:1}
    property real scaleFactor: 0.85

    readonly property var planarConstraints: {
        const mapped = []
        for (let i = 0; i < subscriptions.length; ++i) {
            const spec = subscriptions[i]
            if (!spec || !spec.vp || !spec.direction) {
                mapped.push({direction:null, vp:null, region:"all", weight:1})
                continue
            }
            const marker = spec.vp
            // Reading x/y keeps binding live while marker is dragged.
            const markerX = marker.x, markerY = marker.y
            const surfaceX = surface.x, surfaceY = surface.y
            const local = surface.mapFromItem(marker, marker.width/2, marker.height/2)
            mapped.push({
                direction: {x:spec.direction.x, y:spec.direction.y},
                vp: {x:local.x, y:local.y},
                region: spec.region === undefined ? "all" : spec.region,
                weight: spec.weight === undefined ? 1 : spec.weight
            })
        }
        return mapped
    }
    readonly property bool planarRegionValid: planarConstraints.every(s =>
        s.region === "all" && s.weight === 1)
    readonly property var planarResult: PerspectiveMath.solve(
        width, height, planarConstraints, scaleFactor)

    readonly property var geometryCheck: Geometry.validate(
        width, height, cornerTargets, seamTargets, creaseU, mode, transition,
        meshColumns, meshRows)
    readonly property var surfaceParams: SurfaceModelV2.parameters(
        sceneSnapshot,width,height,mode,creaseU)
    readonly property var surfaceCheck: SurfaceModelV2.validate(
        surfaceParams,transition,Projection,meshColumns,meshRows)
    readonly property bool geometryValid: projectionMode === "surface3d"
        ? surfaceCheck.valid
        : projectionMode === "screenWarp"
          && (mode === "planar" ? planarRegionValid && planarResult.valid
                                : geometryCheck.valid)
    readonly property string diagnostic: projectionMode === "surface3d"
        ? surfaceCheck.diagnostic
        : projectionMode !== "screenWarp" ? "Unknown projection mode"
        : mode === "planar"
          ? (planarRegionValid ? planarResult.message
                + (planarResult.valid
                   ? ", residual " + planarResult.maxError.toFixed(3) + " px" : "")
                + (transition < 1 ? " (VP target at t=1)" : "")
                               : "Planar mode requires region all and weight 1")
          : geometryCheck.diagnostic
    readonly property int invertedTriangleCount: projectionMode === "surface3d"
        ? surfaceCheck.invertedTriangleCount : mode === "planar"
        ? 0 : geometryCheck.invertedTriangleCount
    readonly property int geometryRevision: sceneSnapshot ? sceneSnapshot.revision : 0
    readonly property real maxGuideResidualPx: projectionMode === "surface3d"
        ? surfaceCheck.maxGuideResidualPx : NaN
    readonly property real maxVpError: mode === "planar" ? planarResult.maxError : NaN
    readonly property real transitionEased: Geometry.smoothstep(transition)
    readonly property int leftColumns: Math.max(1, Math.min(meshColumns - 1,
                                              Math.round(meshColumns * creaseU)))
    readonly property var leftCorners: Geometry.patchCorners(
        width, height, cornerTargets, seamTargets, creaseU, mode, "left")
    readonly property var rightCorners: Geometry.patchCorners(
        width, height, cornerTargets, seamTargets, creaseU, mode, "right")

    // One original content tree and one texture. Two adjacent geometry patches
    // sample disjoint U ranges; their shared edge is exactly at creaseU.
    Item {
        id: sourceContent
        objectName: "sourceContent"
        width: surface.width
        height: surface.height
        Rectangle {
            anchors.fill: parent
            z: 1000
            visible: surface.showGrid
            color: "transparent"
            border.color: "#dd1675a8"
            border.width: 1
            Repeater {
                model: 9
                Rectangle {
                    x: index * sourceContent.width / 8
                    width: 1
                    height: sourceContent.height
                    color: "#991675a8"
                }
            }
            Repeater {
                model: 5
                Rectangle {
                    y: index * sourceContent.height / 4
                    height: 1
                    width: sourceContent.width
                    color: "#991675a8"
                }
            }
        }
    }
    ShaderEffectSource {
        id: texture
        objectName: "texture"
        parent: surface
        sourceItem: sourceContent
        hideSource: true
        visible: false
        width: surface.width
        height: surface.height
        live: true

        // High quality texture test
        property real renderScale: 5.0
        textureSize: Qt.size(
        Math.ceil(sourceContent.width * renderScale),
        Math.ceil(sourceContent.height * renderScale)
        )

        mipmap: true
        samples: 4
        smooth: true
    }
    ShaderEffect {
        id: leftPatch
        parent: surface
        z: 10
        visible: surface.projectionMode === "screenWarp"
                 && surface.geometryValid && surface.mode !== "planar"
        x: 0
        y: 0
        width: surface.width * surface.creaseU
        height: surface.height
        mesh: GridMesh { resolution: Qt.size(surface.leftColumns, surface.meshRows) }
        vertexShader: "qrc:/shaders/shaders/surface.vert.qsb"
        property var source: texture
        property real transitionEased: surface.transitionEased
        property real originX: 0
        property real sourceU0: 0
        property real sourceU1: surface.creaseU
        property point topLeft: Qt.point(surface.leftCorners[0].x, surface.leftCorners[0].y)
        property point topRight: Qt.point(surface.leftCorners[1].x, surface.leftCorners[1].y)
        property point bottomLeft: Qt.point(surface.leftCorners[2].x, surface.leftCorners[2].y)
        property point bottomRight: Qt.point(surface.leftCorners[3].x, surface.leftCorners[3].y)
    }
    ShaderEffect {
        id: rightPatch
        parent: surface
        z: 10
        visible: surface.projectionMode === "screenWarp"
                 && surface.geometryValid && surface.mode !== "planar"
        x: surface.width * surface.creaseU
        y: 0
        width: surface.width * (1 - surface.creaseU)
        height: surface.height
        mesh: GridMesh {
            resolution: Qt.size(surface.meshColumns - surface.leftColumns, surface.meshRows)
        }
        vertexShader: "qrc:/shaders/shaders/surface.vert.qsb"
        property var source: texture
        property real transitionEased: surface.transitionEased
        property real originX: rightPatch.x
        property real sourceU0: surface.creaseU
        property real sourceU1: 1
        property point topLeft: Qt.point(surface.rightCorners[0].x, surface.rightCorners[0].y)
        property point topRight: Qt.point(surface.rightCorners[1].x, surface.rightCorners[1].y)
        property point bottomLeft: Qt.point(surface.rightCorners[2].x, surface.rightCorners[2].y)
        property point bottomRight: Qt.point(surface.rightCorners[3].x, surface.rightCorners[3].y)
    }
    ShaderEffect {
        parent: surface
        z: 10
        visible: surface.projectionMode === "screenWarp"
                 && surface.geometryValid && surface.mode === "planar"
        width: surface.width
        height: surface.height
        vertexShader: "qrc:/shaders/shaders/planar.vert.qsb"
        property var source: texture
        property real transitionEased: surface.transitionEased
        property matrix4x4 homography: Qt.matrix4x4(surface.planarResult.matrix)
    }
    component Surface3DPanel: ShaderEffect {
        required property var surfaceItem
        required property var textureSource
        required property var params
        required property real sourceU0
        required property real sourceU1
        required property vector3d uDirection3D
        parent: surfaceItem
        z: 10
        visible: surfaceItem.projectionMode === "surface3d"
                 && surfaceItem.geometryValid
        mesh: GridMesh {
            resolution: Qt.size(Math.max(1,Math.round(
                                    surfaceItem.meshColumns*(sourceU1-sourceU0))),
                                surfaceItem.meshRows)
        }
        vertexShader: "qrc:/shaders/shaders/surface3d.vert.qsb"
        property var source: textureSource
        property real transitionEased: surfaceItem.transitionEased
        property real creaseU: surfaceItem.creaseU
        property real scaleU: params.valid ? params.scaleU : 1
        property real scaleV: params.valid ? params.scaleV : 1
        property real cameraTilt: params.valid ? params.config.tiltRadians : 0
        property real focalX: params.valid ? params.config.fx : 1
        property real focalY: params.valid ? params.config.fy : 1
        property real fisheyeF: params.valid ? params.config.f : 1
        property real viewportWidth: params.valid ? params.config.width : 1
        property real viewportHeight: params.valid ? params.config.height : 1
        property real centerX: params.valid ? params.config.cx : 0
        property real centerY: params.valid ? params.config.cy : 0
        property real sheetX: surfaceItem.x
        property real sheetY: surfaceItem.y
        property real patchOriginX: x
        property int projectionKind: !params.valid ? 0
            : params.config.model === "rectilinear" ? 0
            : params.config.model === "equidistantFisheye" ? 1 : 2
        property int surfaceMode: params.valid && params.mode === "crease" ? 1 : 0
        property vector3d anchor3D: params.valid
            ? Qt.vector3d(params.anchor[0],params.anchor[1],params.anchor[2])
            : Qt.vector3d(0,0,6)
        property vector3d vDirection3D: params.valid
            ? Qt.vector3d(params.verticalDir[0],params.verticalDir[1],params.verticalDir[2])
            : Qt.vector3d(0,1,0)
    }
    Surface3DPanel {
        surfaceItem: surface
        textureSource: texture
        params: surface.surfaceParams
        x: 0
        width: surface.width*surface.creaseU
        height: surface.height
        sourceU0: 0
        sourceU1: surface.creaseU
        uDirection3D: surface.surfaceParams.valid
            ? Qt.vector3d(surface.surfaceParams.leftDir[0],
                          surface.surfaceParams.leftDir[1],
                          surface.surfaceParams.leftDir[2])
            : Qt.vector3d(1,0,0)
    }
    Surface3DPanel {
        surfaceItem: surface
        textureSource: texture
        params: surface.surfaceParams
        x: surface.width*surface.creaseU
        width: surface.width*(1-surface.creaseU)
        height: surface.height
        sourceU0: surface.creaseU
        sourceU1: 1
        uDirection3D: surface.surfaceParams.valid
            ? Qt.vector3d(surface.surfaceParams.rightDir[0],
                          surface.surfaceParams.rightDir[1],
                          surface.surfaceParams.rightDir[2])
            : Qt.vector3d(1,0,0)
    }
}
