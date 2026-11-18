import QtQuick
import QtQuick.Controls.Basic

Item {
    id: overlay
    property var snapshot
    property var sceneController
    property bool showGuides: true
    property bool showVPs: true
    property int selectedFamily: 0
    property int hoveredFamily: -1
    signal familySelected(int familyIndex)
    function edgePoint(d) {
        if(!d) return Qt.point(width/2,height/2)
        const sx=d.x>0 ? (width/2-18)/d.x : d.x<0 ? (-width/2+18)/d.x : 1e9
        const sy=d.y>0 ? (height/2-18)/d.y : d.y<0 ? (-height/2+18)/d.y : 1e9
        const scale=Math.min(sx,sy)
        return Qt.point(width/2+d.x*scale,height/2+d.y*scale)
    }
    Canvas {
        id: guideCanvas
        anchors.fill: parent
        visible: overlay.showGuides
        onPaint: {
            const ctx=getContext("2d")
            ctx.clearRect(0,0,width,height)
            if(!overlay.snapshot) return
            const guides=overlay.snapshot.guides
            for(let i=0;i<guides.length;i++) {
                const g=guides[i]
                ctx.strokeStyle=g.color
                ctx.globalAlpha=g.familyIndex===overlay.selectedFamily ? 0.85 : 0.4
                ctx.lineWidth=g.familyIndex===overlay.selectedFamily ? 2 : 1
                for(const segment of g.segments) {
                    if(segment.length<2) continue
                    ctx.beginPath()
                    ctx.moveTo(segment[0].x,segment[0].y)
                    for(let j=1;j<segment.length;j++)
                        ctx.lineTo(segment[j].x,segment[j].y)
                    ctx.stroke()
                }
            }
            ctx.globalAlpha=1
        }
        Connections {
            target: overlay
            function onSnapshotChanged() { guideCanvas.requestPaint() }
            function onSelectedFamilyChanged() { guideCanvas.requestPaint() }
            function onShowGuidesChanged() { guideCanvas.requestPaint() }
        }
    }
    component VPHandle: Rectangle {
        id: handle
        required property int familyIndex
        required property bool partnerEnd
        objectName: "vpHandle" + familyIndex + (partnerEnd ? "p" : "a")
        property var record: overlay.snapshot.families[familyIndex]
        property var projection: partnerEnd ? record.partner : record.primary
        width: 16; height: 16; radius: 8
        x: projection.positionPx ? projection.positionPx.x-width/2 : 0
        y: projection.positionPx ? projection.positionPx.y-height/2 : 0
        visible: overlay.showVPs && record.valid && projection.kind==="finite"
                 && projection.visibleInFOV && projection.visibleInViewport
        color: record.color
        border.color: "white"
        border.width: familyIndex===overlay.selectedFamily ? 2 : 1
        z: 30
        MouseArea {
            id: ma
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.OpenHandCursor
            onEntered: overlay.hoveredFamily=handle.familyIndex
            onExited: overlay.hoveredFamily=-1
            onPressed: {
                overlay.sceneController.pointerPressCount++
                overlay.familySelected(handle.familyIndex)
            }
            onPositionChanged: mouse => {
                if(!pressed) return
                const p=mapToItem(overlay,mouse.x,mouse.y)
                overlay.sceneController.moveDirection(handle.familyIndex,
                    handle.partnerEnd,p.x,p.y)
            }
        }
        ToolTip.visible: ma.containsMouse
        ToolTip.text: record.id + (partnerEnd ? " −d" : " +d")
                      + " | " + projection.kind
                      + " | d=" + (partnerEnd ? record.partnerDirection3D
                                           : record.direction3D)
        ToolTip.delay: 300
    }
    Repeater {
        model: overlay.snapshot ? overlay.snapshot.families.length : 0
        delegate: Item {
            required property int index
            width: overlay.width
            height: overlay.height
            property var rec: overlay.snapshot.families[index]
            VPHandle { familyIndex: index; partnerEnd: false }
            VPHandle {
                familyIndex: index
                partnerEnd: true
                visible: overlay.sceneController.projection!=="rectilinear"
                         && overlay.showVPs && rec.valid
                         && projection.kind==="finite"
                         && projection.visibleInFOV && projection.visibleInViewport
            }
            Text {
                property var arrowPoint: overlay.edgePoint(rec.primary.directionPx)
                x: arrowPoint.x-16; y: arrowPoint.y-12
                visible: overlay.showVPs && rec.valid
                         && rec.primary.kind==="mathematicalInfinity"
                text: "∞ " + rec.id
                color: rec.color
                font.pixelSize: 13
            }
        }
    }
    Text {
        x: 12; y: 10
        color: "#d8e6f5"
        font.pixelSize: 12
        text: overlay.hoveredFamily>=0 && overlay.snapshot
              ? overlay.snapshot.families[overlay.hoveredFamily].id
                + " | +d / −d derived from one family" : ""
    }
}
