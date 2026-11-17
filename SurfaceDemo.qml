import QtQuick
import QtQuick.Controls.Basic

Item {
    id: demo
    Rectangle { anchors.fill: parent; color: "#161d2b" }

    component TargetHandle: Rectangle {
        id: handle
        width: 18; height: 18
        radius: 9
        z: 20
        color: "#ffbd66"
        border.color: "#26334d"
        border.width: 2
        property string caption: ""
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: -25
            text: handle.caption
            color: "white"
            font.pixelSize: 12
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.OpenHandCursor
            drag.target: handle
        }
    }

    Text {
        x: 30; y: 22
        text: "One real QML sheet • drag VPs or target handles"
        color: "white"
        font.pixelSize: 20
    }
    Text {
        x: 30; y: 52
        text: "Planar VP target uses one homography at t=1. Corner and crease are screen warps."
        color: "#aab9ce"
        font.pixelSize: 13
    }

    PerspectiveSurface {
        id: sheet
        x: 300; y: 220
        width: 440; height: 230
        mode: planarMode.checked ? "planar" : creaseMode.checked ? "crease" : "corner"
        transition: progress.value
        creaseU: seamPosition.value
        showGrid: true
        subscriptions: {
            const all = [
                {vp:leftVP, direction:Qt.point(1,0), region:"all", weight:1},
                {vp:rightVP, direction:Qt.point(0,1), region:"all", weight:1},
                {vp:midVP, direction:Qt.point(1,1), region:"all", weight:1},
                {vp:extraVP, direction:Qt.point(2,1), region:"all", weight:1}
            ]
            return all.slice(0, vpCount.currentIndex+1)
        }
        cornerTargets: [
            Qt.point(tl.x + tl.width/2 - sheet.x, tl.y + tl.height/2 - sheet.y),
            Qt.point(tr.x + tr.width/2 - sheet.x, tr.y + tr.height/2 - sheet.y),
            Qt.point(bl.x + bl.width/2 - sheet.x, bl.y + bl.height/2 - sheet.y),
            Qt.point(br.x + br.width/2 - sheet.x, br.y + br.height/2 - sheet.y)
        ]
        seamTargets: [
            Qt.point(st.x + st.width/2 - sheet.x, st.y + st.height/2 - sheet.y),
            Qt.point(sb.x + sb.width/2 - sheet.x, sb.y + sb.height/2 - sheet.y)
        ]

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: "#eef4fa"
            border.color: "#426485"
            border.width: 2
        }
        Column {
            x: 24; y: 38
            spacing: 20
            Text {
                text: "Original QML content, one texture"
                color: "#254361"
                font.pixelSize: 18
            }
            Row {
                spacing: 18
                Button {
                    text: "Real Button"
                    onClicked: console.log("Surface Button clicked")
                }
                TextField {
                    width: 180
                    text: "Real TextField"
                }
            }
            Text {
                text: "Grid and controls deform together"
                color: "#456987"
            }
        }
    }

    TargetHandle { id: tl; x: sheet.x+10-9; y: sheet.y+20-9
                   caption: "TL"; visible: !planarMode.checked }
    TargetHandle { id: tr; x: sheet.x+415-9; y: sheet.y+8-9
                   caption: "TR"; visible: !planarMode.checked }
    TargetHandle { id: bl; x: sheet.x+20-9; y: sheet.y+213-9
                   caption: "BL"; visible: !planarMode.checked }
    TargetHandle { id: br; x: sheet.x+410-9; y: sheet.y+225-9
                   caption: "BR"; visible: !planarMode.checked }
    TargetHandle {
        id: st; x: sheet.x+250-9; y: sheet.y+45-9
        caption: "Seam top"; visible: creaseMode.checked
        color: "#8ce9c5"
    }
    TargetHandle {
        id: sb; x: sheet.x+205-9; y: sheet.y+205-9
        caption: "Seam bottom"; visible: creaseMode.checked
        color: "#8ce9c5"
    }
    VanishingPoint {
        id: leftVP
        x: 75; y: 165
        label: "VP 1"; pointColor: "#ffb33f"
        visible: planarMode.checked
    }
    VanishingPoint {
        id: rightVP
        x: 1007; y: 165
        label: "VP 2"; pointColor: "#39c7fa"
        visible: planarMode.checked
    }
    VanishingPoint {
        id: midVP
        objectName: "vp3"
        x: (leftVP.x+rightVP.x)/2; y: (leftVP.y+rightVP.y)/2
        label: "VP 3"; pointColor: "#a5ef8a"
        visible: planarMode.checked && vpCount.currentIndex >= 2
    }
    VanishingPoint {
        id: extraVP
        x: (2*leftVP.x+rightVP.x)/3; y: (2*leftVP.y+rightVP.y)/3
        label: "VP 4"; pointColor: "#c59af6"
        visible: planarMode.checked && vpCount.currentIndex >= 3
    }

    Row {
        x: 30; y: 105
        spacing: 18
        Button {
            id: planarMode
            text: "Planar VP"
            checkable: true
            checked: true
            onClicked: {
                checked = true
                cornerMode.checked = false
                creaseMode.checked = false
            }
        }
        Button {
            id: cornerMode
            text: "Corner"
            checkable: true
            checked: false
            onClicked: {
                checked = true
                planarMode.checked = false
                creaseMode.checked = false
            }
        }
        Button {
            id: creaseMode
            text: "Crease"
            checkable: true
            checked: false
            onClicked: {
                checked = true
                planarMode.checked = false
                cornerMode.checked = false
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            color: sheet.geometryValid ? "#99ebbb" : "#fb7185"
            text: "Geometry: " + sheet.diagnostic
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "VP count"
            color: "white"
            visible: planarMode.checked
        }
        ComboBox {
            id: vpCount
            model: ["1", "2", "3", "4"]
            currentIndex: 3
            visible: planarMode.checked
        }
    }
    Row {
        x: 30; y: 555
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Transition " + progress.value.toFixed(2)
            color: "white"
        }
        Slider {
            id: progress
            objectName: "progressSlider"
            width: 320
            from: 0; to: 1; value: 1
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Crease U " + seamPosition.value.toFixed(2)
            color: "white"
        }
        Slider {
            id: seamPosition
            width: 220
            from: 0.1; to: 0.9; value: 0.55
        }
    }
    Text {
        x: 30; y: 610
        color: "#aab9ce"
        text: "VP markers drive planar sheet. Drag VP3/4 off shared line to see rejection. Warped input pending."
    }
}
