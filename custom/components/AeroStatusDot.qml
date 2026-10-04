// AeroStatusDot.qml
// Small colored indicator dot with an optional text label.
// "checking" state pulses subtly to indicate activity.
//
// Properties:
//   status    (string) — "healthy"|"advisory"|"critical"|"unknown"|"checking"
//   label     (string) — text shown beside the dot
//   showLabel (bool)   — whether to show the label

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Row {
    id: root

    property string status:    "unknown"
    property string label:     ""
    property bool   showLabel: true
    property string diagnosticId: ""
    signal diagnosticRequested(string diagnosticId)

    spacing: AeroMetrics.gapSmall
    TapHandler {
        enabled: root.diagnosticId.length > 0
        onTapped: root.diagnosticRequested(root.diagnosticId)
    }

    // ── Dot color resolver ────────────────────────────────────────────────────
    readonly property color _dotColor: {
        switch (root.status) {
        case "healthy":   return AeroColors.healthy
        case "advisory":  return AeroColors.advisory
        case "critical":  return AeroColors.critical
        case "checking":  return AeroColors.accent
        default:          return AeroColors.textMuted   // "unknown"
        }
    }

    // ── Dot ───────────────────────────────────────────────────────────────────
    Rectangle {
        id: dot
        width:  8
        height: 8
        radius: 4
        color:  root._dotColor
        anchors.verticalCenter: parent.verticalCenter

        Behavior on color { ColorAnimation { duration: AeroMotion.color } }

        // Pulsing opacity for "checking" state
        SequentialAnimation {
            id: pulseAnim
            running:   root.status === "checking"
            loops:     Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                target:   dot
                property: "opacity"
                from: 1.0; to: 0.3
                duration: AeroMotion.panel
                easing.type: AeroMotion.easingExit
            }
            NumberAnimation {
                target:   dot
                property: "opacity"
                from: 0.3; to: 1.0
                duration: AeroMotion.panel
                easing.type: AeroMotion.easingEnter
            }
        }

        // Reset opacity when not checking
        onVisibleChanged: {
            if (root.status !== "checking") dot.opacity = 1.0
        }
    }

    // ── Optional label ────────────────────────────────────────────────────────
    Text {
        visible: root.showLabel && root.label !== ""
        text:    root.label
        color:   AeroColors.textSecondary
        font.family:    AeroTypography.family
        font.pixelSize: AeroTypography.caption   // 16px minimum
        anchors.verticalCenter: parent.verticalCenter
    }
}
