import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic

Item {
    id: workbench
    Rectangle { anchors.fill: parent; color: "#101827" }
    PerspectiveSceneController {
        id: scene
        viewportWidth: viewport.width
        viewportHeight: viewport.height
        devicePixelRatio: workbench.Window.window
                          ? workbench.Window.window.devicePixelRatio : 1
    }
    property bool showVPs: true
    property bool showGuides: true
    property bool showGrid: true
    property bool showDiagnostics: true
    property int selectedFamily: 0

    Row {
        x: 18; y: 13
        spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Projection"
            color: "white"
        }
        ComboBox {
            id: projectionBox
            width: 170
            model: ["rectilinear","equidistantFisheye","equirectangular"]
            onActivated: scene.projection=model[currentIndex]
            Connections {
                target: scene
                function onProjectionChanged() {
                    projectionBox.currentIndex=projectionBox.model.indexOf(scene.projection)
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Preset"
            color: "white"
        }
        ComboBox {
            id: presetBox
            width: 90
            model: ["1","2","3","4","5","6","N"]
            currentIndex: 1
            onActivated: scene.loadPreset(model[currentIndex])
            Connections {
                target: scene
                function onPresetKeyChanged() {
                    presetBox.currentIndex=presetBox.model.indexOf(scene.presetKey)
                }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: scene.projection===scene.fixtureProjection
                  ? scene.presetDescription
                  : "Projection override; fixture directions retained"
            color: "#a9c2d9"
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: panel
        x: 14; y: 64
        width: 250
        height: parent.height-210
        color: "#1a2940"
        radius: 6
        border.color: "#38506b"
        Column {
            x: 12; y: 12
            width: parent.width-24
            spacing: 8
            Text { text: "Direction families"; color: "white"; font.pixelSize: 17 }
            Button {
                text: "+ Add family"
                onClicked: scene.addFamily()
            }
            Button {
                text: "− Remove selected"
                enabled: scene.directionFamilies.length>0
                onClicked: {
                    scene.removeFamily(workbench.selectedFamily)
                    workbench.selectedFamily=Math.max(0,Math.min(
                        workbench.selectedFamily,scene.directionFamilies.length-1))
                }
            }
            Flickable {
                width: panel.width-24
                height: Math.max(80,panel.height-y-12)
                contentWidth: width
                contentHeight: familyColumn.implicitHeight
                clip: true
                Column {
                    id: familyColumn
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: scene.snapshot.families.length
                        delegate: Rectangle {
                            required property int index
                            property var rec: scene.snapshot.families[index]
                            width: familyColumn.width
                            height: 43
                            radius: 4
                            color: index===workbench.selectedFamily ? "#314861" : "#24364c"
                            border.color: rec.color || "#667"
                            Text {
                                x: 8; y: 4
                                text: rec.id + "  d=" +
                                      (rec.valid ? rec.direction3D.map(v=>v.toFixed(2)).join(",") : "invalid")
                                color: "white"
                                font.pixelSize: 11
                            }
                            Text {
                                x: 8; y: 23
                                text: rec.valid ? "+ " + workbench.vpStatus(rec.primary)
                                                  + " | − " + workbench.vpStatus(rec.partner)
                                                : rec.reason
                                color: "#b5d4e8"
                                font.pixelSize: 10
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: workbench.selectedFamily=index
                            }
                        }
                    }
                }
            }
        }
    }
    function vpStatus(vp) {
        if(vp.kind==="mathematicalInfinity") return "∞"
        if(vp.kind==="invalid") return "invalid"
        if(!vp.visibleInFOV) return "outside FOV"
        return vp.visibleInViewport ? "visible" : "offscreen"
    }

    Rectangle {
        id: viewport
        x: 275; y: 64
        width: parent.width-290
        height: parent.height-210
        color: "#17263a"
        border.color: "#45617d"
        border.width: 1
        clip: true

        Rectangle {
            visible: scene.projection==="equidistantFisheye"
            width: Math.min(viewport.width,viewport.height)
            height: width
            x: (viewport.width-width)/2
            y: (viewport.height-height)/2
            radius: width/2
            color: "#1c3048"
            border.color: "#5f7897"
            border.width: 1
        }
        Rectangle {
            visible: scene.projection==="equirectangular"
            x: 1; y: 0; width: 1; height: viewport.height
            color: "#8aa0ba"
        }
        PerspectiveSurface {
            id: alignedSheet
            x: viewport.width/2-145
            y: viewport.height/2-60
            width: 290; height: 120
            projectionMode: "surface3d"
            sceneSnapshot: scene.snapshot
            mode: scene.presetKey==="2" || scene.presetKey==="3"
                  ? (surfaceMode.currentIndex===1 ? "crease" : "planar") : "planar"
            creaseU: 0.55
            transition: transitionControl.value
            showGrid: workbench.showGrid
            Rectangle {
                anchors.fill: parent
                color: "#e7f0f8"
                border.color: "#375675"
                border.width: 2
                Text {
                    x: 10; y: 7
                    text: "One constructed QML sheet"
                    color: "#254361"
                    font.pixelSize: 12
                }
                Row {
                    x: 10; y: 37
                    spacing: 8
                    Button { text: "Real Button" }
                    TextField { width: 155; text: "Real TextField" }
                }
            }
        }
        PerspectiveGuideOverlay {
            id: overlay
            anchors.fill: parent
            z: 20
            snapshot: scene.snapshot
            sceneController: scene
            showGuides: workbench.showGuides
            showVPs: workbench.showVPs
            selectedFamily: workbench.selectedFamily
            onFamilySelected: familyIndex => workbench.selectedFamily=familyIndex
        }
    }
    Row {
        x: 18; y: parent.height-91
        spacing: 14
        CheckBox { text: "VPs"; checked: true; palette.windowText: "white"
                   onToggled: workbench.showVPs=checked }
        CheckBox { text: "Guides"; checked: true; palette.windowText: "white"
                   onToggled: workbench.showGuides=checked }
        CheckBox { text: "Source grid"; checked: true; palette.windowText: "white"
                   onToggled: workbench.showGrid=checked }
        CheckBox { text: "Diagnostics"; checked: true; palette.windowText: "white"
                   onToggled: workbench.showDiagnostics=checked }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "θ tol °"
            color: "white"
        }
        TextField {
            width: 51
            text: "0.1"
            validator: DoubleValidator { bottom: 0.0001; top: 45 }
            onEditingFinished: {
                const value=Number(text)
                if(Number.isFinite(value) && value>0)
                    scene.angularToleranceRad=value*Math.PI/180
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "px tol"
            color: "white"
        }
        TextField {
            width: 51
            text: "0.5"
            validator: DoubleValidator { bottom: 0.001; top: 100 }
            onEditingFinished: {
                const value=Number(text)
                if(Number.isFinite(value) && value>0)
                    scene.pixelTolerancePhysical=value
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Revision " + scene.snapshot.revision + "  |  DPR "
                  + scene.devicePixelRatio.toFixed(2)
                  + "  |  edits " + scene.pointerPressCount + "/" + scene.pointerMoveCount
            color: "#a9c2d9"
        }
    }
    Row {
        x: 18; y: parent.height-129
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Sheet"
            color: "white"
        }
        ComboBox {
            id: surfaceMode
            objectName: "surfaceModeSelector"
            width: 105
            model: ["planar","corner fold"]
            currentIndex: 1
            enabled: scene.presetKey==="2" || scene.presetKey==="3"
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Transition " + transitionControl.value.toFixed(2)
            color: "white"
        }
        Slider {
            id: transitionControl
            objectName: "workbenchTransition"
            from: 0; to: 1; value: 1
            width: 240
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: alignedSheet.geometryValid
                  ? alignedSheet.diagnostic
                    + (Number.isFinite(alignedSheet.maxGuideResidualPx)
                       ? " | guide target " + alignedSheet.maxGuideResidualPx.toFixed(3) + " px"
                       : "")
                                            : "Invalid: " + alignedSheet.diagnostic
            color: alignedSheet.geometryValid ? "#9ee7b8" : "#fb7185"
        }
    }
    Text {
        x: 18; y: parent.height-53
        width: parent.width-36
        color: "#a9c2d9"
        font.pixelSize: 12
        visible: workbench.showDiagnostics
        property var rec: scene.snapshot.families.length
                          ? scene.snapshot.families[Math.min(workbench.selectedFamily,
                                                             scene.snapshot.families.length-1)] : null
        text: rec && rec.valid
              ? rec.id + ": " + workbench.vpStatus(rec.primary)
                + ", partner " + workbench.vpStatus(rec.partner)
                + ", display=" + rec.effective.kind
                + ", θmax=" + (Number.isFinite(rec.effective.thetaMaxRad)
                              ? rec.effective.thetaMaxRad.toFixed(5) : "n/a") + " rad"
                + ", error=" + (Number.isFinite(rec.effective.errorPhysicalPx)
                               ? rec.effective.errorPhysicalPx.toFixed(3) : "n/a")
                + " physical px"
                + (scene.projection==="rectilinear" ? "  |  Ω 290×120"
                                                      : "  |  Ω visible viewport")
              : "No valid selected family"
    }
    Text {
        x: 18; y: parent.height-29
        color: "#f1be87"
        font.pixelSize: 12
        text: "Constructed zero-thickness UI sheet uses same projection as guides. Warped input pending."
    }
}
