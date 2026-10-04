import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.Toolbar
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    property var vehicle
    property bool hideLogo: false
    signal diagnosticRequested(string diagnosticId)

    readonly property bool compact: width < 1500
    readonly property bool veryCompact: width < 1180
    readonly property var primaryBattery: vehicle && vehicle.batteries && vehicle.batteries.count > 0
                                                  ? vehicle.batteries.get(0) : null
    readonly property real batteryPercent: primaryBattery ? Number(primaryBattery.percentRemaining.value) : NaN
    readonly property int satelliteCount: vehicle && vehicle.gps ? Number(vehicle.gps.count.value) : -1

    height: AeroMetrics.topBarHeight
    color: AeroColors.surface
    border.color: AeroColors.border
    border.width: 1

    // Read drone name from settings
    readonly property string droneName: {
        var fact = AeroTHONManager.droneNameFact
        return fact ? fact.rawValue : "AeroTHON-01"
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: AeroMetrics.gapSmall

        Image {
            source: "qrc:/Custom/AeroTHON/assets/aerokle_logo_dark.png"
            Layout.preferredHeight: 28
            Layout.preferredWidth: compact ? 44 : 52
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            opacity: root.hideLogo ? 0.0 : 1.0
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 24
            color: AeroColors.border
        }

        // Drone name beside logo
        Text {
            text: root.droneName
            color: AeroColors.textPrimary
            font.family: AeroTypography.family
            font.pixelSize: AeroTypography.caption
            font.weight: Font.DemiBold
            visible: root.droneName.length > 0
        }

        Rectangle {
            visible: root.droneName.length > 0
            Layout.preferredWidth: 1
            Layout.preferredHeight: 24
            color: AeroColors.border
        }

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: root.compact ? 5 : 8
            Layout.alignment: Qt.AlignVCenter

            AeroStatusDot {
                label: root.veryCompact ? "PX4" : (root.vehicle ? "PX4" : "PX4 OFFLINE")
                status: root.vehicle && !root.vehicle.vehicleLinkManager.commLost ? "healthy" : "critical"
                diagnosticId: "PX4"
                onDiagnosticRequested: (diagId) => root.diagnosticRequested(diagId)
            }

            Rectangle {
                visible: !root.veryCompact
                implicitWidth: gpsText.implicitWidth + 14
                implicitHeight: 26
                color: AeroColors.surfaceRaised
                border.color: AeroColors.border
                radius: AeroMetrics.radiusSmall
                Text {
                    id: gpsText
                    anchors.centerIn: parent
                    text: root.satelliteCount >= 0 ? qsTr("GPS %1").arg(root.satelliteCount) : qsTr("GPS N/A")
                    color: root.satelliteCount >= 6 ? AeroColors.textPrimary : AeroColors.textSecondary
                    font.family: AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                }
                TapHandler { onTapped: root.diagnosticRequested("GPS") }
            }

            Rectangle {
                visible: !root.veryCompact
                implicitWidth: batteryText.implicitWidth + 14
                implicitHeight: 26
                color: AeroColors.surfaceRaised
                border.color: isNaN(root.batteryPercent) ? AeroColors.border
                              : root.batteryPercent < 20 ? AeroColors.critical
                              : root.batteryPercent < 35 ? AeroColors.advisory : AeroColors.border
                radius: AeroMetrics.radiusSmall
                Text {
                    id: batteryText
                    anchors.centerIn: parent
                    text: isNaN(root.batteryPercent) ? qsTr("BAT N/A") : qsTr("BAT %1%").arg(Math.round(root.batteryPercent))
                    color: AeroColors.textPrimary
                    font.family: AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                }
                TapHandler { onTapped: root.diagnosticRequested("BAT") }
            }

            Rectangle {
                id: modeChip
                implicitWidth: Math.max(54, modeText.implicitWidth + 16)
                implicitHeight: 26
                radius: AeroMetrics.radiusSmall
                color: AeroColors.surfaceRaised
                border.color: AeroColors.borderStrong
                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: root.vehicle ? root.vehicle.flightMode : qsTr("MODE N/A")
                    color: AeroColors.textPrimary
                    font.family: AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                }
                TapHandler {
                    enabled: !!root.vehicle
                    onTapped: mainWindow.showIndicatorDrawer(flightModesComponent, modeChip)
                }
            }

            Rectangle {
                id: flightTimeChip
                visible: !root.veryCompact && root.vehicle
                implicitWidth: timeText.implicitWidth + 14
                implicitHeight: 26
                color: (root.vehicle && root.vehicle.armed) ? AeroColors.accentSubtle : AeroColors.surfaceRaised
                border.color: (root.vehicle && root.vehicle.armed) ? AeroColors.accent : AeroColors.border
                radius: AeroMetrics.radiusSmall
                Text {
                    id: timeText
                    anchors.centerIn: parent
                    text: {
                        if (!root.vehicle || !root.vehicle.flightTime) return "00:00:00"
                        var s = Math.floor(Number(root.vehicle.flightTime.rawValue))
                        if (s <= 0) return "00:00:00"
                        var h = Math.floor(s / 3600)
                        var m = Math.floor((s % 3600) / 60)
                        var sec = s % 60
                        var hStr = (h < 10 ? "0" : "") + h
                        var mStr = (m < 10 ? "0" : "") + m
                        var sStr = (sec < 10 ? "0" : "") + sec
                        return hStr + ":" + mStr + ":" + sStr
                    }
                    color: (root.vehicle && root.vehicle.armed) ? AeroColors.accent : AeroColors.textSecondary
                    font.family: AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.caption
                    font.weight: (root.vehicle && root.vehicle.armed) ? Font.Bold : Font.Normal
                }
            }

        }
    }

    Component {
        id: flightModesComponent
        Rectangle {
            implicitWidth: 240
            implicitHeight: modeColumn.implicitHeight + 20
            color: AeroColors.surfaceRaised
            border.color: AeroColors.borderStrong
            ColumnLayout {
                id: modeColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: AeroMetrics.gapSmall
                Text {
                    text: qsTr("FLIGHT MODE")
                    color: AeroColors.textSecondary
                    font.pixelSize: AeroTypography.caption
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: root.vehicle ? root.vehicle.flightModes : []
                    QGCDelayButton {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData
                        delay: QGroundControl.settingsManager.flightModeSettings.requireModeChangeConfirmation.rawValue ? defaultDelay : 0
                        onActivated: {
                            if (root.vehicle) root.vehicle.flightMode = modelData
                            mainWindow.closeIndicatorDrawer()
                        }
                    }
                }
            }
        }
    }

}
