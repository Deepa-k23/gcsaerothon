import QtQuick
import QtQuick.Layouts
import QtMultimedia
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    // ── Properties ────────────────────────────────────────────────────────────
    // cameraState: "NO SIGNAL" | "CONNECTING" | "INITIALIZING" | "LIVE"
    //            | "DEGRADED" | "RECONNECTING" | "FAILED"
    property string cameraLabel:  ""
    property string displayLabel: ""  // User-configurable name (from Settings)
    property string source:       ""
    readonly property string cameraState: receiver.videoState
    readonly property real fpsCurrent: receiver.currentFPS
    property string layoutState:  "NORMAL"
    property Item expansionHost

    signal layoutRequested(string state)
    signal diagnosticRequested(string diagnosticId)

    onCameraStateChanged: {
        var key = "CAMERA:" + root.cameraLabel
        if (root.cameraState === "LIVE") {
            AeroAlertModel.resolveAlert(key)
        } else if (root.cameraState === "DEGRADED") {
            AeroAlertModel.raiseAlert(key, "WARNING", root.cameraLabel, root.cameraLabel + " video degraded",
                                      "Decoded frames are stale or arriving below the usable rate")
        } else if (root.cameraState === "FAILED") {
            AeroAlertModel.raiseAlert(key, "CRITICAL", root.cameraLabel, root.cameraLabel + " video failed",
                                      "Receiver exhausted the current start attempt", true)
        }
    }

    property bool showBorder: false

    // ── Appearance ────────────────────────────────────────────────────────────
    color:  showBorder ? AeroColors.surface : "transparent"
    radius: showBorder ? AeroMetrics.radiusPanel : 0

    border.width: showBorder ? 1 : 0
    border.color: {
        switch (root.cameraState) {
        case "LIVE":         return AeroColors.accent
        case "INITIALIZING": return AeroColors.borderStrong
        case "DEGRADED":     return AeroColors.advisory
        case "FAILED":       return AeroColors.critical
        default:             return AeroColors.border
        }
    }

    Behavior on border.color { ColorAnimation { duration: AeroMotion.color } }

    VideoOutput {
        id: videoOutput
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
        visible: root.cameraState === "LIVE" || root.cameraState === "DEGRADED"
    }

    AeroVideoReceiver {
        id: receiver
        objectName: root.cameraLabel === "FPV" ? "aerothonFpv" : "aerothonNadir"
        source: root.source
        videoOutput: videoOutput
        Component.onCompleted: start()
    }

    // ── Camera label (top-left) ───────────────────────────────────────────────
    Text {
        id:    camLabel
        text:  root.displayLabel.length > 0 ? root.displayLabel : root.cameraLabel
        color: AeroColors.textSecondary
        font.pixelSize: AeroTypography.caption   // 16px
        anchors {
            top:  parent.top
            left: parent.left
            topMargin:  8
            leftMargin: 8
        }
        TapHandler { onTapped: root.diagnosticRequested(root.cameraLabel) }
    }

    // ── FPS indicator (top-right, visible only when live) ─────────────────────
    Text {
        id:      fpsText
        text:    root.fpsCurrent.toFixed(1) + " fps"
        color:   AeroColors.textMuted
        font.pixelSize: AeroTypography.caption   // 16px
        visible: root.cameraState === "LIVE" && root.fpsCurrent > 0
        anchors {
            top:   parent.top
            right: parent.right
            topMargin:   8
            rightMargin: 8
        }
    }

    // ── State overlay (shown when NOT live) ───────────────────────────────────
    Item {
        id:           stateOverlay
        anchors.fill: parent
        visible:      root.cameraState !== "LIVE"

        // NO SIGNAL
        Text {
            anchors.centerIn: parent
            text:    "NO SIGNAL"
            color:   AeroColors.textMuted
            font.pixelSize: AeroTypography.caption   // 16px
            visible: root.cameraState === "NO SIGNAL"
        }

        // CONNECTING (dot + text + pulse animation)
        Row {
            anchors.centerIn: parent
            spacing: 6
            visible: root.cameraState === "CONNECTING" || root.cameraState === "RECONNECTING"

            Rectangle {
                id:     connectDot
                width:  8
                height: 8
                radius: 4
                color:  AeroColors.accent
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running:  root.cameraState === "CONNECTING" || root.cameraState === "RECONNECTING"
                    loops:    Animation.Infinite
                    NumberAnimation { to: 0.2; duration: AeroMotion.panel; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: AeroMotion.panel; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text:  root.cameraState
                color: AeroColors.textSecondary
                font.pixelSize: AeroTypography.caption   // 16px
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // INITIALIZING
        Text {
            anchors.centerIn: parent
            text:    "INITIALIZING"
            color:   AeroColors.accent
            font.pixelSize: AeroTypography.caption   // 16px
            visible: root.cameraState === "INITIALIZING"
        }

        // DEGRADED
        Text {
            anchors.centerIn: parent
            text:    "DEGRADED"
            color:   AeroColors.advisory
            font.pixelSize: AeroTypography.caption   // 16px
            visible: root.cameraState === "DEGRADED"
        }

        // FAILED
        Text {
            anchors.centerIn: parent
            text:    "FAILED"
            color:   AeroColors.critical
            font.pixelSize: AeroTypography.caption   // 16px
            visible: root.cameraState === "FAILED"
        }
    }

    // ── Expand button (bottom-right) ──────────────────────────────────────────
    Text {
        id:    expandBtn
        text:  "⛶"
        color: AeroColors.textSecondary
        font.pixelSize: 16
        anchors {
            bottom: parent.bottom
            right:  parent.right
            bottomMargin: 6
            rightMargin:  8
        }

        TapHandler {
            onTapped: root.layoutRequested(root.layoutState === "NORMAL" ? "EXPANDED" : "NORMAL")
        }
    }

    // ── Double-tap for fullscreen ─────────────────────────────────────────────
    TapHandler {
        acceptedButtons: Qt.LeftButton
        onDoubleTapped:  root.layoutRequested("FULLSCREEN")
    }

    states: [
        State {
            name: "EXPANDED"
            when: root.layoutState === "EXPANDED" && root.expansionHost
            ParentChange {
                target: root
                parent: root.expansionHost
                x: AeroMetrics.gapLarge
                y: AeroMetrics.gapLarge
                width: root.expansionHost.width - AeroMetrics.gapLarge * 2
                height: root.expansionHost.height - AeroMetrics.gapLarge * 2
            }
            PropertyChanges { root.z: 90 }
        },
        State {
            name: "FULLSCREEN"
            when: root.layoutState === "FULLSCREEN" && root.expansionHost
            ParentChange {
                target: root
                parent: root.expansionHost
                x: 0
                y: 0
                width: root.expansionHost.width
                height: root.expansionHost.height
            }
            PropertyChanges { root.z: 100; root.radius: 0 }
        }
    ]

    transitions: Transition {
        ParentAnimation {
            NumberAnimation {
                properties: "x,y,width,height"
                duration: AeroMotion.panel
                easing.type: Easing.OutCubic
            }
        }
    }
}
