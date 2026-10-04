// AeroPX4Doctor.qml
// PX4 Log Analyser launcher view without WebEngine dependency.

import QtQuick
import QtQuick.Layouts
import QGroundControl
import QGroundControl.Controls
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    color: AeroColors.surface

    // ── Header ────────────────────────────────────────────────────────────────
    RowLayout {
        id: header
        anchors {
            top:   parent.top
            left:  parent.left
            right: parent.right
        }
        height: 48
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: AeroColors.surface

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 16
                text: "PX4 DOCTOR · LOG ANALYZER"
                color: AeroColors.textPrimary
                font.family: AeroTypography.family
                font.pixelSize: AeroTypography.section
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }

            // Back to GCS button
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 16
                implicitWidth: backText.implicitWidth + 24
                implicitHeight: 30
                radius: AeroMetrics.radiusSmall
                color: backMouse.containsMouse ? AeroColors.surfaceHover : AeroColors.surfaceRaised
                border.color: AeroColors.border
                border.width: 1

                Text {
                    id: backText
                    anchors.centerIn: parent
                    text: "← Back to Flight View"
                    color: AeroColors.textPrimary
                    font.family: AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    font.weight: Font.Medium
                }

                HoverHandler { id: backMouse }
                TapHandler { onTapped: mainWindow.showFlyView() }
            }
        }
    }

    // Separator
    Rectangle {
        id: sep
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: AeroColors.border
    }

    // ── Content Area ──────────────────────────────────────────────────────────
    Rectangle {
        anchors {
            top:    sep.bottom
            left:   parent.left
            right:  parent.right
            bottom: parent.bottom
            margins: 24
        }
        color: AeroColors.surfaceRaised
        radius: AeroMetrics.radiusPanel
        border.color: AeroColors.border
        border.width: 1

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16
            width: Math.min(parent.width - 48, 560)

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56
                height: 56
                radius: 28
                color: AeroColors.surface
                border.color: AeroColors.accent
                border.width: 1.5

                Text {
                    anchors.centerIn: parent
                    text: "🩺"
                    font.pixelSize: 26
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "PX4 Log Diagnostics & Analysis"
                color: AeroColors.textPrimary
                font.family: AeroTypography.family
                font.pixelSize: AeroTypography.heading
                font.weight: Font.Bold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Analyze flight logs, EKF consistency, vibration metrics, actuator performance, and automated fault diagnoses directly via the PX4 Log Analyzer suite."
                color: AeroColors.textSecondary
                font.family: AeroTypography.family
                font.pixelSize: AeroTypography.body
            }

            Item { Layout.preferredHeight: 8 }

            AeroButton {
                Layout.alignment: Qt.AlignHCenter
                text: "Open PX4 Log Analyzer ↗"
                accent: true
                onClicked: {
                    Qt.openUrlExternally("https://log-analyser.app/")
                }
            }
        }
    }
}
