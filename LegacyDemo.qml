import QtQuick
import QtQuick.Controls.Basic

Item {
    id: root

    Rectangle { anchors.fill: parent; color: "#161d2b" }

    Item {
        id: scene
        anchors.fill: parent
        property real surfaceScale: 0.85

        Text {
            x: 24; y: 22
            text: "N-VP • move the markers to test compatibility"
            color: "white"; font.pixelSize: 18
        }
        Text {
            x: 24; y: 52
            text: "A single UI plane requires compatible VP directions on one vanishing line."
            color: "#aab9ce"; font.pixelSize: 12
        }

        // Four distinct VPs. Their starting positions are mathematically
        // consistent for directions (1,0), (0,1), (1,1), (2,1).
        VanishingPoint {
            id: leftVP
            x: 75; y: 215
            label: "VP 1"; pointColor: "#ffb33f"
        }
        VanishingPoint {
            id: rightVP
            x: 1007; y: 215
            label: "VP 2"; pointColor: "#39c7fa"
        }
        VanishingPoint {
            id: midVP
            x: 541; y: 215
            label: "VP 3"; pointColor: "#a5ef8a"
        }
        VanishingPoint {
            id: extraVP
            x: (2*75+1007)/3; y: 215
            label: "VP 4"; pointColor: "#c59af6"
        }

        // 1 VP: horizontal source edges converge to the left VP;
        // vertical source edges remain parallel.
        PerspectiveItem {
            id: onePlane
            x: 135; y: 360; width: 235; height: 105
            subscriptions: [
                { vp: leftVP, direction: Qt.point(1,0) }
            ]
            scaleFactor: scene.surfaceScale
            Button {
                id: oneButton
                anchors.fill: parent
                text: "1 VP Button"
                background: Rectangle {
                    radius: 6; antialiasing: true
                    color: oneButton.down ? "#c8d5e2" : "#e9edf4"
                    border.color: "#7b8ba4"; border.width: 1
                }
                onClicked: console.log("oneVP clicked")
            }
        }

        // 2 independent source directions: the entire item is transformed
        // by ONE exact planar homography.
        PerspectiveItem {
            id: twoPlane
            x: 430; y: 360; width: 235; height: 105
            subscriptions: [
                { vp: leftVP, direction: Qt.point(1,0) },
                { vp: rightVP, direction: Qt.point(0,1) }
            ]
            scaleFactor: scene.surfaceScale
            Button {
                id: twoButton
                anchors.fill: parent
                text: "2 VP Button"
                background: Rectangle {
                    radius: 6; antialiasing: true
                    color: twoButton.down ? "#c8d5e2" : "#e9edf4"
                    border.color: "#7b8ba4"; border.width: 1
                }
                onClicked: console.log("twoVP clicked")
            }
        }

        // N=4: directions 3 and 4 constrain/validate the exact projectivity.
        // Drag VP3/VP4 away from their valid position to see rejection.
        PerspectiveItem {
            id: fourPlane
            x: 735; y: 360; width: 235; height: 105
            subscriptions: [
                { vp: leftVP, direction: Qt.point(1,0) },
                { vp: rightVP, direction: Qt.point(0,1) },
                { vp: midVP, direction: Qt.point(1,1) },
                { vp: extraVP, direction: Qt.point(2,1) }
            ]
            scaleFactor: scene.surfaceScale
            TextField {
                anchors.fill: parent
                text: "4-VP TextField"
                font.pixelSize: 15
                background: Rectangle {
                    radius: 6; antialiasing: true
                    color: "#f8fafc"
                    border.color: fourPlane.valid ? "#7b8ba4" : "#fb7185"
                    border.width: 2
                }
            }
        }

        Column {
            x: 135; y: 500
            spacing: 8
            Text { text: "1 VP: " + onePlane.diagnostic
                   color: onePlane.valid ? "#99ebbb" : "#fb7185"; font.pixelSize: 12 }
            Text { text: "2 VP: " + twoPlane.diagnostic
                   color: twoPlane.valid ? "#99ebbb" : "#fb7185"; font.pixelSize: 12 }
            Text { text: "4 VP: " + fourPlane.diagnostic
                   color: fourPlane.valid ? "#99ebbb" : "#fb7185"; font.pixelSize: 12 }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 30
            spacing: 14
            Text {
                anchors.verticalCenter: parent.verticalCenter
                color: "white"; text: "Scale: " + scene.surfaceScale.toFixed(2)
            }
            Slider {
                id: scaler
                width: 250
                from: 0.2; to: 1.5; value: scene.surfaceScale
                onMoved: scene.surfaceScale = value
            }
            Button {
                text: "Restore compatible VP3 / VP4"
                onClicked: {
                    // Same-center geometry for marker x/y coordinates.
                    midVP.x = (leftVP.x+rightVP.x)/2
                    midVP.y = (leftVP.y+rightVP.y)/2
                    extraVP.x = (2*leftVP.x+rightVP.x)/3
                    extraVP.y = (2*leftVP.y+rightVP.y)/3
                }
            }
        }
    }
}
