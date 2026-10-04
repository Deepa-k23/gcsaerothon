import QtQuick
import QtQuick.Layouts
import QGroundControl 1.0
import QGroundControl.Controls 1.0
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root
    
    property var vehicle
    property bool showBorder: false

    color: showBorder ? AeroColors.surface : "transparent"
    radius: showBorder ? AeroMetrics.radiusPanel : 0
    border.color: AeroColors.border
    border.width: showBorder ? 1 : 0
    
    implicitHeight: 80

    // 1. GS (Ground Speed)
    readonly property real gs: vehicle && vehicle.groundSpeed ? Number(vehicle.groundSpeed.rawValue) : NaN
    // 2. ALT (Relative Altitude)
    readonly property real alt: vehicle && vehicle.altitudeRelative ? Number(vehicle.altitudeRelative.rawValue) : NaN
    // 3. VS (Climb Rate)
    readonly property real vs: vehicle && vehicle.climbRate ? Number(vehicle.climbRate.rawValue) : NaN
    // 4. BATTERY
    readonly property real battery: (vehicle && vehicle.batteries && vehicle.batteries.count > 0) ? Number(vehicle.batteries.get(0).percentRemaining.rawValue) : NaN
    // 5. DISTANCE TO NEXT WAYPOINT
    readonly property real wpDist: vehicle && vehicle.distanceToNextWP ? Number(vehicle.distanceToNextWP.rawValue) : -1
    // 6. FLIGHT TIME
    readonly property int flightTimeSecs: vehicle && vehicle.flightTime ? Number(vehicle.flightTime.rawValue) : 0
    
    function formatTime(s) {
        if (s <= 0) return "00:00:00"
        var h = Math.floor(s / 3600)
        var m = Math.floor((s % 3600) / 60)
        var sec = Math.floor(s % 60)
        var hStr = (h < 10 ? "0" : "") + h.toString()
        var mStr = (m < 10 ? "0" : "") + m.toString()
        var sStr = (sec < 10 ? "0" : "") + sec.toString()
        return hStr + ":" + mStr + ":" + sStr
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8
        
        // GS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "GS"
                color: AeroColors.textSecondary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: (root.vehicle && !isNaN(root.gs)) ? root.gs.toFixed(2) + " m/s" : "--"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }

        // ALT
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "ALT"
                color: AeroColors.textSecondary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: (root.vehicle && !isNaN(root.alt)) ? root.alt.toFixed(2) + " m" : "--"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
        
        // VS
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "VS"
                color: AeroColors.textSecondary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: (root.vehicle && !isNaN(root.vs)) ? (root.vs >= 0 ? "+" : "") + root.vs.toFixed(2) + " m/s" : "--"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
        
        // BATTERY
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "BAT"
                color: AeroColors.textSecondary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: (root.vehicle && !isNaN(root.battery)) ? root.battery.toFixed(0) + "%" : "--"
                color: (root.vehicle && root.battery < 20) ? AeroColors.critical : AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
        
        // NEXT WP
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "NEXT WP"
                color: AeroColors.textSecondary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: (root.vehicle && !isNaN(root.wpDist) && root.wpDist >= 0) ? root.wpDist.toFixed(2) + " m" : "--"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
        
        // FLIGHT TIME
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text {
                text: "TIME"
                color: AeroColors.textSecondary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                text: root.vehicle ? root.formatTime(root.flightTimeSecs) : "00:00:00"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily
                font.pixelSize: 14
                font.weight: Font.Bold
            }
        }
    }
}
