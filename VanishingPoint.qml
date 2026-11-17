import QtQuick

Item {
    id: marker
    width: 14
    height: 14
    z: 100

    property string label: "VP"
    property color pointColor: "#f8ac32"

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: marker.pointColor
        border.color: "#243041"
        border.width: 1
    }
    Text {
        x: marker.width + 8
        anchors.verticalCenter: parent.verticalCenter
        text: marker.label
        color: marker.pointColor
        font.pixelSize: 12
    }
    MouseArea {
        anchors.fill: parent
        anchors.margins: -8
        cursorShape: Qt.OpenHandCursor
        drag.target: marker
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: marker.parent ? marker.parent.width-marker.width : 0
        drag.maximumY: marker.parent ? marker.parent.height-marker.height : 0
    }
}
