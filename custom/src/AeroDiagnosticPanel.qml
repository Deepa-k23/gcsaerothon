import QtQuick
import QtQuick.Layouts
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"

Rectangle {
    id: root
    required property string diagnosticId
    signal closeRequested()
    property string selectedDiagnostic: diagnosticId
    onDiagnosticIdChanged: selectedDiagnostic = diagnosticId
    width: 320
    implicitHeight: details.implicitHeight + 32
    color: AeroColors.surfaceRaised
    radius: AeroMetrics.radiusPanel
    border.width: 1
    border.color: AeroColors.borderStrong

    function statusColor(status) {
        if (status === "NORMAL" || status === "LIVE" || status === "ONLINE") return AeroColors.healthy
        if (status === "WARNING" || status === "DEGRADED") return AeroColors.advisory
        if (status === "CRITICAL" || status === "FAILED" || status === "LOST") return AeroColors.critical
        return AeroColors.textMuted
    }
    function rowsFor(id) {
        switch (id) {
        case "GPS": return [
            ["STATUS", AeroOperationalHealth.gpsStatus],
            ["FIX", AeroOperationalHealth.gpsAvailable ? String(AeroOperationalHealth.gpsFix) : "N/A"],
            ["SATELLITES", AeroOperationalHealth.gpsAvailable ? String(AeroOperationalHealth.gpsSatellites) : "N/A"],
            ["HDOP", AeroOperationalHealth.gpsAvailable ? AeroOperationalHealth.gpsHdop.toFixed(1) : "N/A"]]
        case "EKF": return [
            ["STATUS", AeroOperationalHealth.ekfStatus],
            ["GPS GLITCH", AeroOperationalHealth.ekfAvailable ? (AeroOperationalHealth.ekfGpsGlitch ? "YES" : "NO") : "N/A"],
            ["ACCEL ERROR", AeroOperationalHealth.ekfAvailable ? (AeroOperationalHealth.ekfAccelError ? "YES" : "NO") : "N/A"],
            ["HORIZ RATIO", AeroOperationalHealth.ekfAvailable ? AeroOperationalHealth.ekfHorizontalPositionRatio.toFixed(2) : "N/A"],
            ["VERT RATIO", AeroOperationalHealth.ekfAvailable ? AeroOperationalHealth.ekfVerticalPositionRatio.toFixed(2) : "N/A"]]
        case "BATTERY": return [
            ["STATUS", AeroOperationalHealth.batteryStatus],
            ["REMAINING", AeroOperationalHealth.batteryAvailable ? AeroOperationalHealth.batteryPercent.toFixed(0) + "%" : "N/A"],
            ["VOLTAGE", AeroOperationalHealth.batteryAvailable ? AeroOperationalHealth.batteryVoltage.toFixed(2) + " V" : "N/A"],
            ["CHARGE STATE", AeroOperationalHealth.batteryAvailable ? String(AeroOperationalHealth.batteryChargeState) : "N/A"]]
        case "WFB": return [
            ["STATUS", AeroTHONManager.wfbAvailable ? ["NORMAL", "WARNING", "CRITICAL", "UNKNOWN"][AeroTHONManager.wfbState] : "UNKNOWN"],
            ["RSSI", AeroTHONManager.rssiAvailable ? AeroTHONManager.rssiDbm + " dBm" : "N/A"],
            ["SNR", AeroTHONManager.snrAvailable ? AeroTHONManager.snrDb.toFixed(1) + " dB" : "N/A"],
            ["PACKET LOSS", AeroTHONManager.packetLossAvailable ? AeroTHONManager.packetLossPct.toFixed(1) + "%" : "N/A"],
            ["BITRATE", AeroTHONManager.bitrateAvailable ? AeroTHONManager.bitrateMbps.toFixed(1) + " Mbit/s" : "N/A"]]
        case "AXON": return [["STATUS", ["UNKNOWN", "ONLINE", "DEGRADED", "LOST"][AeroTHONManager.axonState]],
            ["CPU", AeroTHONManager.axonState ? AeroTHONManager.cpuPct.toFixed(0) + "%" : "N/A"],
            ["RAM", AeroTHONManager.axonState ? AeroTHONManager.ramPct.toFixed(0) + "%" : "N/A"],
            ["TEMPERATURE", AeroTHONManager.axonState ? AeroTHONManager.tempC.toFixed(1) + "°C" : "N/A"]]
        case "FPV": return [["STATUS", AeroTHONManager.fpvFps > 0 ? "LIVE" : "UNKNOWN"],
            ["DECODED FPS", AeroTHONManager.fpvFps > 0 ? AeroTHONManager.fpvFps.toFixed(1) : "N/A"],
            ["PIPELINE", AeroTHONManager.gstreamerState.length ? AeroTHONManager.gstreamerState : "UNKNOWN"]]
        case "NADIR": return [["STATUS", AeroTHONManager.nadirFps > 0 ? "LIVE" : "UNKNOWN"],
            ["DECODED FPS", AeroTHONManager.nadirFps > 0 ? AeroTHONManager.nadirFps.toFixed(1) : "N/A"],
            ["VISION FPS", AeroTHONManager.inferenceFps > 0 ? AeroTHONManager.inferenceFps.toFixed(1) : "N/A"]]
        default: return [["STATUS", "UNKNOWN"], ["DETAIL", "No diagnostic source selected"]]
        }
    }

    ColumnLayout {
        id: details
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text { text: root.selectedDiagnostic + " DIAGNOSTICS"; color: AeroColors.textPrimary; font.pixelSize: AeroTypography.section; font.weight: Font.DemiBold; Layout.fillWidth: true }
            Text { text: "×"; color: AeroColors.textSecondary; font.pixelSize: AeroTypography.body; TapHandler { onTapped: root.closeRequested() } }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["GPS", "EKF", "BATTERY", "WFB", "AXON", "FPV", "NADIR"]
                Rectangle {
                    required property string modelData
                    width: tabText.implicitWidth + 12
                    height: 26
                    radius: AeroMetrics.radiusSmall
                    color: root.selectedDiagnostic === modelData ? AeroColors.accentSubtle : AeroColors.surface
                    border.width: 1
                    border.color: root.selectedDiagnostic === modelData ? AeroColors.accent : AeroColors.border
                    Text { id: tabText; anchors.centerIn: parent; text: modelData; color: AeroColors.textSecondary; font.pixelSize: AeroTypography.caption }
                    TapHandler { onTapped: root.selectedDiagnostic = modelData }
                }
            }
        }
        Repeater {
            model: root.rowsFor(root.selectedDiagnostic)
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                Text { text: modelData[0]; color: AeroColors.textMuted; font.pixelSize: AeroTypography.caption; Layout.fillWidth: true }
                Text { text: modelData[1]; color: root.statusColor(modelData[1]); font.pixelSize: AeroTypography.body; font.family: AeroTypography.dataFamily }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Advisory only. PX4 remains the authority for flight and arming decisions."
            wrapMode: Text.WordWrap
            color: AeroColors.textMuted
            font.pixelSize: AeroTypography.caption
        }
    }
}
