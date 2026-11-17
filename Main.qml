import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic

Window {
    id: root
    width: 1100
    height: 720
    visible: true
    color: "#161d2b"
    title: "Perspective Surface — Qt Quick"

    property bool legacyView: false
    Loader {
        anchors.fill: parent
        source: root.legacyView ? "LegacyDemo.qml" : "SurfaceDemo.qml"
    }
    Button {
        z: 100
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 18
        text: root.legacyView ? "Surface demo" : "Legacy VP demo"
        onClicked: root.legacyView = !root.legacyView
    }
}
