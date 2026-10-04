// AeroStatusChip.qml
// Compact status chip for the top bar / system-health rows: status dot + label
// + optional value in a subtle pill. Tap navigates to diagnostics.
//
// Properties:
//   status       (string) — "healthy"|"advisory"|"critical"|"unknown"|"checking"
//   label        (string) — chip label
//   value        (string) — optional value shown in mono beside the label
//   diagnosticId (string) — when set, tapping raises diagnosticRequested(id)

import QtQuick
import QtQuick.Layouts
import "qrc:/Custom/AeroTHON/theme"

Rectangle {
    id: root

    property string status: "unknown"
    property string label: ""
    property string value: ""
    property string diagnosticId: ""
    signal diagnosticRequested(string diagnosticId)

    implicitHeight: AeroMetrics.statusRowHeight
    implicitWidth: content.implicitWidth + AeroMetrics.gapLarge
    color: AeroColors.surfaceCard
    radius: AeroMetrics.radiusControl
    border.width: AeroMetrics.borderThin

    // ── State color resolver ───────────────────────────────────────────────────
    readonly property color _stateColor: {
        switch (root.status) {
        case "healthy":   return AeroColors.healthy
        case "advisory":  return AeroColors.advisory
        case "critical":  return AeroColors.critical
        case "checking":  return AeroColors.accent
        default:          return AeroColors.textMuted
        }
    }
    border.color: Qt.rgba(root._stateColor.r, root._stateColor.g, root._stateColor.b, 0.55)

    Behavior on border.color { ColorAnimation { duration: AeroMotion.statusSync } }

    TapHandler {
        enabled: root.diagnosticId.length > 0
        onTapped: root.diagnosticRequested(root.diagnosticId)
    }

    // ── Pulsing activity ring for "checking" ───────────────────────────────────
    SequentialAnimation {
        running: root.status === "checking"
        loops: Animation.Infinite
        NumberAnimation { target: dot; property: "opacity"; from: 1.0; to: 0.35; duration: AeroMotion.panel; easing.type: AeroMotion.easingExit }
        NumberAnimation { target: dot; property: "opacity"; from: 0.35; to: 1.0; duration: AeroMotion.panel; easing.type: AeroMotion.easingEnter }
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: AeroMetrics.gap
        anchors.rightMargin: AeroMetrics.gap
        spacing: AeroMetrics.gapSmall

        Rectangle {
            id: dot
            width: 7
            height: 7
            radius: width / 2
            color: root._stateColor
            Behavior on color { ColorAnimation { duration: AeroMotion.color } }
        }

        Text {
            text: root.label.toUpperCase()
            color: AeroColors.textSecondary
            font.family: AeroTypography.family
            font.pixelSize: AeroTypography.micro
            font.weight: AeroTypography.weightDemiBold
            font.letterSpacing: AeroTypography.labelSpacing
        }

        Text {
            visible: root.value !== ""
            text: root.value
            color: AeroColors.textPrimary
            font.family: AeroTypography.dataFamily
            font.pixelSize: AeroTypography.caption
            font.weight: AeroTypography.weightMedium
        }
    }
}