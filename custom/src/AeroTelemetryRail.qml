// AeroTelemetryRail.qml
// AeroTHON-GCS V2 — Bottom telemetry strip (54px height, full width).
//
// Displays: GS | VS | ALT | HDG | BAT | GPS | WFB | WP | TIME
// Each cell has a label, value, unit, optional sparkline, and animated colour.

import QtQuick
import QtQuick.Layouts
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    // ── Public API ──────────────────────────────────────────────────────────────
    property var vehicle
    signal diagnosticRequested(string diagnosticId)

    // ── Geometry ────────────────────────────────────────────────────────────────
    height: AeroMetrics.telemetryRailHeight   // 54px
    color:  AeroColors.surface

    // Top border
    Rectangle {
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 1
        color:  AeroColors.border
    }

    // ── Heading wrap-safe interpolation ────────────────────────────────────────
    property real rawHeadingValue: vehicle && vehicle.heading ? Number(vehicle.heading.value) : 0
    property real _displayHeading: 0

    function shortestAngular(from, to) {
        var diff = ((to - from) % 360 + 540) % 360 - 180
        return from + diff
    }

    onRawHeadingValueChanged: {
        _displayHeading = shortestAngular(_displayHeading, rawHeadingValue)
    }

    Behavior on _displayHeading {
        NumberAnimation { duration: AeroMotion.heading }
    }

    // ── Null-safe vehicle props ──────────────────────────────────────────────────
    readonly property real   groundSpeed:      vehicle && vehicle.groundSpeed      ? Number(vehicle.groundSpeed.value)      : 0.0
    readonly property real   verticalSpeed:    vehicle && vehicle.climbRate        ? Number(vehicle.climbRate.value)        : 0.0
    readonly property real   altitudeRelative: vehicle && vehicle.altitudeRelative ? Number(vehicle.altitudeRelative.value) : 0.0
    readonly property real   battery:          vehicle && vehicle.batteries && vehicle.batteries.count > 0 ? Number(vehicle.batteries.get(0).percentRemaining.value) : (vehicle && vehicle.battery && vehicle.battery.percentRemaining ? Number(vehicle.battery.percentRemaining.value) : 0.0)

    // GPS text: "3D-<count>" / "2D" / "NONE"
    readonly property int    _gpsType:  vehicle && vehicle.gps && vehicle.gps.lock   ? Number(vehicle.gps.lock.value)  : 0
    readonly property int    _gpsCnt:   vehicle && vehicle.gps && vehicle.gps.count  ? Number(vehicle.gps.count.value) : 0
    readonly property string gpsText: {
        if (_gpsType >= 3) return "3D (" + _gpsCnt + ")"
        if (_gpsType === 2) return "2D (" + _gpsCnt + ")"
        return _gpsCnt > 0 ? _gpsCnt + " sats" : "NONE"
    }
    readonly property color  gpsColor: {
        if (_gpsType >= 3) return AeroColors.healthy
        if (_gpsType === 2) return AeroColors.advisory
        return AeroColors.critical
    }

    // WFB from AeroTHONManager (snrDb, wfbState is int enum: 0=Normal,1=Warning,2=Critical)
    readonly property bool   wfbAvailable: typeof AeroTHONManager !== "undefined" && AeroTHONManager.wfbAvailable
    readonly property real   wfbSnr:    wfbAvailable && AeroTHONManager.snrAvailable ? AeroTHONManager.snrDb : NaN
    readonly property int    _wfbState: wfbAvailable ? AeroTHONManager.wfbState : 3
    readonly property color  wfbColor: {
        if (!wfbAvailable) return AeroColors.textMuted
        if (_wfbState === 0) return AeroColors.healthy
        if (_wfbState === 1) return AeroColors.advisory
        return AeroColors.critical
    }

    // WP
    readonly property int currentWP: vehicle && vehicle.missionItemIndex ? Number(vehicle.missionItemIndex.rawValue) : (vehicle && vehicle.currentWaypointIndex !== undefined ? vehicle.currentWaypointIndex : 0)
    readonly property int totalWP: vehicle && vehicle.missionManager && vehicle.missionManager.missionItems ? vehicle.missionManager.missionItems.count : 0

    // Battery colour
    readonly property color  batColor: {
        if (battery < 20) return AeroColors.critical
        if (battery < 40) return AeroColors.advisory
        return AeroColors.textPrimary
    }

    // ── Rolling history buffers ─────────────────────────────────────────────────
    property var gsHistory:  []
    property var altHistory: []
    property var batHistory: []
    property var wfbHistory: []

    Connections {
        target: typeof AeroTHONManager !== "undefined" ? AeroTHONManager : null
        function onDisplayUpdateReady() {
            if (!vehicle) return
            var gs  = vehicle.groundSpeed      ? Number(vehicle.groundSpeed.value)      : 0
            var alt = vehicle.altitudeRelative ? Number(vehicle.altitudeRelative.value) : 0
            var bat = root.battery
            var snr = wfbSnr

            gsHistory  = [...gsHistory.slice( -(AeroChartStyle.windowSpeed    - 1)), gs ]
            altHistory = [...altHistory.slice(-(AeroChartStyle.windowAltitude - 1)), alt]
            batHistory = [...batHistory.slice(-(AeroChartStyle.windowSpeed    - 1)), bat]
            if (!isNaN(snr))
                wfbHistory = [...wfbHistory.slice(-(AeroChartStyle.windowSpeed - 1)), snr]
        }
    }

    readonly property int flightTimeSeconds: vehicle && vehicle.flightTime ? Math.floor(Number(vehicle.flightTime.rawValue)) : 0
    readonly property string flightTimeText: {
        var elapsed = Math.floor(Math.max(0, flightTimeSeconds))
        var h = Math.floor(elapsed / 3600)
        var m = Math.floor((elapsed % 3600) / 60)
        var s = elapsed % 60
        var hStr = (h < 10 ? "0" : "") + h.toString()
        var mStr = (m < 10 ? "0" : "") + m.toString()
        var sStr = (s < 10 ? "0" : "") + s.toString()
        return hStr + ":" + mStr + ":" + sStr
    }

    // ── Cell template ───────────────────────────────────────────────────────────
    component TelemetryCell: Item {
        id: cell
        property string cellLabel:     ""
        property string cellValue:     ""
        property real   cellValueNum:  0.0
        property bool   isNumeric:     false
        property int    precision:     2
        property string cellUnit:      ""
        property color  valueColor:    AeroColors.textPrimary
        property bool   showSparkline: false
        property var    sparklineData: []
        property string diagnosticId:  ""

        implicitWidth:  68
        Layout.fillHeight: true

        property real _animValue: cell.cellValueNum
        Behavior on _animValue {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: updateFlash
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 2
            color:  AeroColors.accent
            opacity: 0.0
        }
        
        onCellValueChanged: if (!isNumeric) flashAnim.restart()
        onCellValueNumChanged: if (isNumeric) flashAnim.restart()

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: updateFlash; property: "opacity"; from: 1.0; to: 0.0; duration: 300 }
        }

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           cell.cellLabel
                color:          AeroColors.textMuted
                font.family:    AeroTypography.family
                font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Text {
                    text:           cell.isNumeric ? cell._animValue.toFixed(cell.precision) : cell.cellValue
                    color:          cell.valueColor
                    font.family:    AeroTypography.dataFamily
                    font.pixelSize: AeroTypography.telemetry
                    font.features:  {"tnum": 1}
                }
                Text {
                    text:           cell.cellUnit
                    color:          AeroColors.textMuted
                    font.family:    AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    anchors.bottom: parent.bottom
                    bottomPadding:  3
                }
            }

            AeroSparkline {
                visible:           cell.showSparkline
                model:             cell.sparklineData
                width:             40
                height:            16
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
        TapHandler {
            enabled: cell.diagnosticId.length > 0
            onTapped: root.diagnosticRequested(cell.diagnosticId)
        }
    }

    // ── Cell row ────────────────────────────────────────────────────────────────
    RowLayout {
        anchors.fill:         parent
        anchors.leftMargin:   10
        anchors.rightMargin:  10
        spacing: 0

        // 1. Ground Speed
        TelemetryCell {
            cellLabel:     "GS"
            isNumeric: true
            cellValueNum: root.groundSpeed
            precision: 2
            cellUnit:      "m/s"
            showSparkline: true
            sparklineData: root.gsHistory
        }

        AeroDivider { Layout.fillHeight: true }

        // 2. Vertical Speed
        Item {
            implicitWidth:  68
            Layout.fillHeight: true
            
            property real _animVS: root.verticalSpeed
            Behavior on _animVS { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
            on_AnimVSChanged: vsFlashAnim.restart()
            
            Rectangle {
                id: vsUpdateFlash
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 2
                color: AeroColors.accent
                opacity: 0.0
            }
            SequentialAnimation {
                id: vsFlashAnim
                NumberAnimation { target: vsUpdateFlash; property: "opacity"; from: 1.0; to: 0.0; duration: 300 }
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "VS"
                    color:          AeroColors.textMuted
                    font.family:    AeroTypography.family
                    font.pixelSize: AeroTypography.caption
                    font.capitalization: Font.AllUppercase
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 2
                    Text {
                        text: {
                            var v = parent.parent.parent._animVS
                            return (v >= 0 ? "+" : "") + v.toFixed(2)
                        }
                        color:          AeroColors.textPrimary
                        font.family:    AeroTypography.dataFamily
                        font.pixelSize: AeroTypography.telemetry
                        font.features:  {"tnum": 1}
                    }
                    Text {
                        text:           "m/s"
                        color:          AeroColors.textMuted
                        font.family:    AeroTypography.family
                        font.pixelSize: AeroTypography.caption
                        anchors.bottom: parent.bottom
                        bottomPadding:  3
                    }
                }
                AeroTrendIndicator {
                    trend: root.verticalSpeed > 0.05 ? 1 : (root.verticalSpeed < -0.05 ? -1 : 0)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        AeroDivider { Layout.fillHeight: true }

        // 3. Altitude
        TelemetryCell {
            cellLabel:     "ALT"
            isNumeric: true
            cellValueNum: root.altitudeRelative
            precision: 2
            cellUnit:      "m"
            showSparkline: true
            sparklineData: root.altHistory
        }

        AeroDivider { Layout.fillHeight: true }

        // 4. Heading
        TelemetryCell {
            cellLabel: "HDG"
            isNumeric: true
            cellValueNum: root._displayHeading
            precision: 2
            cellUnit:  "°"
        }

        AeroDivider { Layout.fillHeight: true }

        // 5. Battery
        TelemetryCell {
            cellLabel:     "BAT"
            isNumeric: true
            cellValueNum: root.battery
            precision: 0
            cellUnit:      "%"
            showSparkline: true
            sparklineData: root.batHistory
            valueColor:    root.batColor
            diagnosticId:  "BATTERY"
        }

        AeroDivider { Layout.fillHeight: true }

        // 6. GPS
        TelemetryCell {
            cellLabel:  "GPS"
            cellValue:  root.gpsText
            cellUnit:   ""
            valueColor: root.gpsColor
            diagnosticId: "GPS"
        }

        AeroDivider { Layout.fillHeight: true }

        // 7. WFB link
        TelemetryCell {
            cellLabel:  "WFB"
            isNumeric: !isNaN(root.wfbSnr)
            cellValueNum: isNaN(root.wfbSnr) ? 0 : root.wfbSnr
            cellValue: "N/A"
            precision: 1
            cellUnit:   isNaN(root.wfbSnr) ? "" : "dB"
            valueColor: root.wfbColor
            diagnosticId: "WFB"
        }

        AeroDivider { Layout.fillHeight: true }

        // 8. Waypoint
        TelemetryCell {
            cellLabel: "WP"
            cellValue: root.totalWP > 0 ? (root.currentWP + " / " + root.totalWP) : "--"
            cellUnit:  ""
        }

        AeroDivider { Layout.fillHeight: true }

        // 9. Current arm-to-disarm flight time
        TelemetryCell {
            cellLabel: "FLIGHT TIME"
            cellValue: root.flightTimeText
            cellUnit:  ""
        }

        // Right spring
        Item { Layout.fillWidth: true }
    }
}
