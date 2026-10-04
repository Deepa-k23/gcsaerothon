// AeroPayloadConfirmation.qml
// AeroTHON-GCS V2 — Safety confirmation modal for payload release.
//
// Covers parent with a dimmed backdrop.
// Centre panel: AeroTechnicalFrame, title, info rows, Cancel / Confirm buttons.
// CONFIRM only shown when vehicle.armed; otherwise shows an advisory warning.

import QtQuick
import QtQuick.Layouts
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Item {
    id: root

    // ── Public API ──────────────────────────────────────────────────────────────
    property var    vehicle
    property string taskName: vehicle && vehicle.currentMissionDescription
                              ? vehicle.currentMissionDescription : "Unknown Task"

    signal confirmed()
    signal cancelled()

    // ── Geometry ────────────────────────────────────────────────────────────────
    anchors.fill: parent
    z: 50

    // ── Dimmed backdrop ─────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: AeroColors.scrim

        TapHandler {
            onTapped: root.cancelled()
        }
    }

    // ── Centre panel ────────────────────────────────────────────────────────────
    AeroTechnicalFrame {
        id: panel
        width:  300
        height: armedCheck.visible ? 200 : 230   // taller when advisory shown
        anchors.centerIn: parent

        // Stop backdrop tap from leaking through the panel
        TapHandler { onTapped: {} }

        ColumnLayout {
            anchors.fill:    parent
            anchors.margins: 20
            spacing:         12

            // Title
            Text {
                Layout.fillWidth: true
                text:               "RELEASE PAYLOAD?"
                color:              AeroColors.textPrimary
                font.family:        AeroTypography.family
                font.pixelSize:     AeroTypography.caption
                font.weight:        Font.DemiBold
                font.capitalization: Font.AllUppercase
                horizontalAlignment: Text.AlignHCenter
            }

            // Info: task name
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:           "TASK"
                    color:          AeroColors.textMuted
                    font.family:    AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    font.capitalization: Font.AllUppercase
                }
                Item { Layout.fillWidth: true }
                Text {
                    text:           root.taskName
                    color:          AeroColors.textPrimary
                    font.family:    AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                    elide:          Text.ElideRight
                    Layout.maximumWidth: 160
                }
            }

            // Info: armed status
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text:           "ARMED"
                    color:          AeroColors.textMuted
                    font.family:    AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    font.capitalization: Font.AllUppercase
                }
                Item { Layout.fillWidth: true }
                Text {
                    text:  vehicle && vehicle.armed ? "YES" : "NO"
                    color: vehicle && vehicle.armed ? AeroColors.healthy : AeroColors.critical
                    font.family:    AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                    font.weight:    Font.DemiBold
                }
            }

            // Advisory text (when NOT armed)
            Text {
                id: notArmedAdvisory
                Layout.fillWidth: true
                visible:          !(vehicle && vehicle.armed)
                text:             "Vehicle must be ARMED to release payload"
                color:            AeroColors.advisory
                font.family:      AeroTypography.family
                font.pixelSize:   AeroTypography.caption
                wrapMode:         Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Item { Layout.fillHeight: true }

            // Button row
            RowLayout {
                id: armedCheck
                Layout.fillWidth: true
                spacing: 8

                // CANCEL (ghost)
                AeroButton {
                    Layout.fillWidth: true
                    label:       "CANCEL"
                    buttonStyle: "ghost"
                    onClicked: root.cancelled()
                }

                // CONFIRM RELEASE (critical / red) — only when armed
                AeroButton {
                    Layout.fillWidth: true
                    visible:  !!vehicle && vehicle.armed
                    label:       "CONFIRM RELEASE"
                    buttonState: "critical"
                    onClicked: {
                        root.confirmed()
                    }
                }
            }
        }
    }

    // ── Entry animation ─────────────────────────────────────────────────────────
    opacity: 0

    Component.onCompleted: {
        opacity = 1
    }

    Behavior on opacity {
        NumberAnimation { duration: AeroMotion.alert }
    }
}
