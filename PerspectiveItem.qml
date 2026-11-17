import QtQuick
import "PerspectiveMath.js" as PerspectiveMath

Item {
    id: surface

    // Proposed custom API: each subscription binds a LOCAL direction to a VP.
    // [{ vp: vpLeft, direction: Qt.point(1, 0) }, ...]
    // VP and PerspectiveItem must share the same untransformed parent here.
    property var subscriptions: []
    property real scaleFactor: 1.0

    // Keep native QML Button / TextField. No 3D geometry, no Canvas.
    layer.enabled: false

    readonly property var localConstraints: {
        const result = []
        for (let i=0; i<subscriptions.length; ++i) {
            const s=subscriptions[i]
            if (s && s.vp && s.direction) {
                // Read QML properties inside the binding so dragging a VP
                // re-evaluates the matrix without signal subscriptions.
                const marker=s.vp
                const localX=marker.x+marker.width/2-surface.x
                const localY=marker.y+marker.height/2-surface.y
                result.push({vp:{x:localX,y:localY},
                             direction:{x:s.direction.x,y:s.direction.y}})
            }
        }
        return result
    }

    readonly property var result: PerspectiveMath.solve(
        width, height, localConstraints, scaleFactor)
    readonly property bool valid: result.valid
    readonly property string diagnostic: result.message
    readonly property real maxVpError: result.maxError

    transform: Matrix4x4 {
        matrix: Qt.matrix4x4(surface.result.matrix)
    }
}
