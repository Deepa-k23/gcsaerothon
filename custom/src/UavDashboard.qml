import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Item {
    id: root

    // ── External props ────────────────────────────────────────────────────────
    property var mapControl

    // ── Vehicle ───────────────────────────────────────────────────────────────
    property var vehicle:    QGroundControl.multiVehicleManager.activeVehicle
    property bool hasVehicle: vehicle !== null

    // ── Layout ratios / widths ────────────────────────────────────────────────
    property real leftColumnRatio: AeroMetrics.leftColumnRatio
    property real rightColumnRatio: AeroMetrics.rightColumnRatio

    property real leftW: Math.max(
        AeroMetrics.leftColumnMin,
        Math.min(AeroMetrics.leftColumnMax, root.width * leftColumnRatio)
    )
    property real rightW: Math.max(
        AeroMetrics.rightColumnMin,
        Math.min(AeroMetrics.rightColumnMax, root.width * rightColumnRatio)
    )

    // ── Screen / overlay state ────────────────────────────────────────────────
    property string activeScreen:        "flight"
    property bool   payloadConfirmVisible: false
    property var detectionMapLayer: null
    property string activeDiagnostic: ""

    function navigateTo(screenId) {
        switch (screenId) {
        case "flight":
            root.activeScreen = screenId
            mainWindow.showFlyView()
            break
        case "plan":
            root.activeScreen = screenId
            mainWindow.showPlanView()
            break
        case "vehicle":
            root.activeScreen = screenId
            mainWindow.showVehicleConfig()
            break
        case "params":
            root.activeScreen = screenId
            mainWindow.showVehicleConfigParametersPage()
            break
        case "logs":
            root.activeScreen = screenId
            mainWindow.showAnalyzeTool()
            break
        case "settings":
            root.activeScreen = screenId
            mainWindow.showSettingsTool()
            break
        case "px4doctor":
            root.activeScreen = screenId
            mainWindow.showTool(qsTr("PX4 Doctor"),
                                "qrc:/qml/QGroundControl/FlyView/AeroPX4Doctor.qml",
                                "/qmlimages/Analyze.svg")
            break
        case "mission":
            // The AeroTHON task graph is an overlay on the authoritative QGC
            // mission rather than a replacement Plan backend.
            root.activeScreen = screenId
            mainWindow.showFlyView()
            break
        }
    }

    function ensureDetectionMapLayer() {
        if (root.mapControl && !root.detectionMapLayer)
            root.detectionMapLayer = detectionMapLayerComponent.createObject(root.mapControl)
    }

    onMapControlChanged: ensureDetectionMapLayer()
    Component.onCompleted: {
        ensureDetectionMapLayer()
        AeroMotion.reduceMotion = AeroTHONManager.reduceMotion
    }
    Connections {
        target: AeroTHONManager
        function onReduceMotionChanged() { AeroMotion.reduceMotion = AeroTHONManager.reduceMotion }
    }

    Component {
        id: detectionMapLayerComponent
        AeroDetectionMapLayer { }
    }

    // ── Keyboard shortcuts ────────────────────────────────────────────────────
    function triggerVehicleAction(actionId) {
        mainWindow.triggerAeroVehicleAction(actionId)
    }

    Connections {
        target: mainWindow
        function onAeroPayloadRequest() { root.payloadConfirmVisible = true }
        function onAeroEscapeRequest() {
            if (root.payloadConfirmVisible) {
                root.payloadConfirmVisible = false
            } else if (root.activeDiagnostic.length > 0) {
                root.activeDiagnostic = ""
            } else if (cameraColumn.cameraExpanded) {
                cameraColumn.restoreNormalLayout()
            }
        }
    }





    // ── Left panel ────────────────────────────────────────────────────────────
    AeroLeftPanel {
        id: leftPanel
        anchors {
            left:   parent.left
            top:    parent.top
            bottom: parent.bottom
        }
        width:   root.leftW
        vehicle: root.vehicle
        onActionRequested: function(actionId) {
            if (actionId === "mission") {
                // Use the native QGC/PX4 mission workflow (safety-gated)
                AeroTHONManager.startNativeMission()
            } else {
                root.triggerVehicleAction(actionId)
            }
        }
    }

    // ── Camera column (right) ─────────────────────────────────────────────────
    AeroCameraColumn {
        id: cameraColumn
        anchors {
            right:  parent.right
            top:    parent.top
            bottom: parent.bottom
        }
        width: root.rightW
        expansionHost: root
        onDiagnosticRequested: function(diagnosticId) { root.activeDiagnostic = diagnosticId }
    }

    AeroDiagnosticPanel {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: 12
        z: 45
        diagnosticId: root.activeDiagnostic
        visible: root.activeDiagnostic.length > 0
        onCloseRequested: root.activeDiagnostic = ""
    }

    // ── Payload confirmation overlay ──────────────────────────────────────────
    AeroPayloadConfirmation {
        id:      payloadConfirmation
        anchors.centerIn: parent
        z:       50
        visible: root.payloadConfirmVisible
        onConfirmed: {
            root.payloadConfirmVisible = false
            if (root.hasVehicle) {
                // Phase 8 will wire up the actual drop command
                console.log("[UavDashboard] Payload release confirmed")
            }
        }
        onCancelled: {
            root.payloadConfirmVisible = false
        }
    }
}
