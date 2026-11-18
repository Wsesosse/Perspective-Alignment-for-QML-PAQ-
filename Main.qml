import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic

Window {
    id: root
    width: 1100
    height: 720
    visible: true
    color: "#161d2b"
    title: "PAQ V2 Perspective Workbench"

    property int viewIndex: 0
    Loader {
        anchors.fill: parent
        source: ["PerspectiveWorkbench.qml","SurfaceDemo.qml","LegacyDemo.qml"][root.viewIndex]
    }
    Button {
        z: 100
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 18
        text: ["Surface demo","Legacy demo","V2 workbench"][root.viewIndex]
        onClicked: root.viewIndex = (root.viewIndex+1)%3
    }
}
