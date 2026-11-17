import QtQuick
import "SurfaceGeometry.js" as Geometry
import "PerspectiveMath.js" as PerspectiveMath

Item {
    id: surface
    objectName: "surface"
    default property alias content: sourceContent.data

    property real transition: 0
    property string mode: "corner"             // planar | corner | crease
    property string projectionMode: "screenWarp" // surface3d is a later milestone
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
    readonly property bool geometryValid: projectionMode === "screenWarp"
        && (mode === "planar" ? planarRegionValid && planarResult.valid
                              : geometryCheck.valid)
    readonly property string diagnostic: projectionMode !== "screenWarp"
        ? "projectionMode surface3d is not implemented"
        : mode === "planar"
          ? (planarRegionValid ? planarResult.message
                + (planarResult.valid
                   ? ", residual " + planarResult.maxError.toFixed(3) + " px" : "")
                + (transition < 1 ? " (VP target at t=1)" : "")
                               : "Planar mode requires region all and weight 1")
          : geometryCheck.diagnostic
    readonly property int invertedTriangleCount: mode === "planar"
        ? 0 : geometryCheck.invertedTriangleCount
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
    }
    ShaderEffect {
        id: leftPatch
        parent: surface
        z: 10
        visible: surface.geometryValid && surface.mode !== "planar"
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
        visible: surface.geometryValid && surface.mode !== "planar"
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
        visible: surface.geometryValid && surface.mode === "planar"
        width: surface.width
        height: surface.height
        vertexShader: "qrc:/shaders/shaders/planar.vert.qsb"
        property var source: texture
        property real transitionEased: surface.transitionEased
        property matrix4x4 homography: Qt.matrix4x4(surface.planarResult.matrix)
    }
}
