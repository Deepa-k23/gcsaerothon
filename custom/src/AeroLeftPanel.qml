import QtQuick
import QtQuick.Layouts
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    // ── Properties ────────────────────────────────────────────────────────────
    property var vehicle

    signal actionRequested(string actionId)
    signal navigateRequested(string screenId)

    // ── Single Outer Continuous Dock ──────────────────────────────────────────
    color: AeroColors.surface
    border.color: AeroColors.border
    border.width: 1
    radius: AeroMetrics.radiusPanel
    clip: true

    Column {
        anchors.fill: parent
        spacing: 0

        // Attitude / Horizon indicator
        AeroHorizon {
            id: horizon
            width: parent.width
            height: 180
            vehicle: root.vehicle
            showBorder: false
        }

        // 1px Divider
        Rectangle {
            id: div1
            width: parent.width
            height: 1
            color: AeroColors.border
        }

        // Quick action buttons
        AeroQuickActions {
            id: quickActions
            width: parent.width
            height: quickActions.implicitHeight
            vehicle: root.vehicle
            showBorder: false
            onActionRequested: function(actionId) {
                root.actionRequested(actionId)
            }
        }

        // 1px Divider
        Rectangle {
            id: div2
            width: parent.width
            height: 1
            color: AeroColors.border
        }

        // Message / event feed (fills remaining space)
        AeroMessageFeed {
            id: messageFeed
            width: parent.width
            height: Math.max(80, parent.height - horizon.height - div1.height - quickActions.height - div2.height - div3.height - telemetryBox.height)
            vehicle: root.vehicle
            showBorder: false
        }

        // 1px Divider
        Rectangle {
            id: div3
            width: parent.width
            height: 1
            color: AeroColors.border
        }

        // Compact Telemetry Box
        AeroCompactTelemetryBox {
            id: telemetryBox
            width: parent.width
            height: 64
            vehicle: root.vehicle
            showBorder: false
        }
    }
}
