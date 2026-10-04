import QtQuick
import QtQuick.Layouts
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    property Item expansionHost
    signal diagnosticRequested(string diagnosticId)
    readonly property bool cameraExpanded: fpvPanel.layoutState !== "NORMAL" || nadirPanel.layoutState !== "NORMAL"

    // Read camera names from settings
    readonly property string camera1Label: {
        var fact = AeroTHONManager.camera1NameFact
        return fact ? fact.rawValue : "OAK D Lite"
    }
    readonly property string camera2Label: {
        var fact = AeroTHONManager.camera2NameFact
        return fact ? fact.rawValue : "Arducam"
    }

    function setCameraLayout(panel, state) {
        fpvPanel.layoutState = panel === fpvPanel ? state : "NORMAL"
        nadirPanel.layoutState = panel === nadirPanel ? state : "NORMAL"
    }

    function restoreNormalLayout() {
        fpvPanel.layoutState = "NORMAL"
        nadirPanel.layoutState = "NORMAL"
    }

    // ── Single Outer Continuous Dock ──────────────────────────────────────────
    color: AeroColors.surface
    border.color: AeroColors.border
    border.width: 1
    radius: AeroMetrics.radiusPanel
    clip: true

    Column {
        anchors.fill: parent
        spacing: 0

        // FPV panel (OAK-D Lite)
        AeroCameraPanel {
            id: fpvPanel
            width: parent.width
            height: Math.floor((parent.height - 1) * 0.5)
            cameraLabel: "FPV"
            // Verified WFB ground stream: MPEG-TS/H.264 over UDP.
            source: "mpegts://0.0.0.0:5600"
            displayLabel: root.camera1Label
            expansionHost: root.expansionHost
            showBorder: false
            onLayoutRequested: function(state) { root.setCameraLayout(fpvPanel, state) }
            onDiagnosticRequested: function(diagnosticId) { root.diagnosticRequested(diagnosticId) }
        }

        // 1px Horizontal Divider
        Rectangle {
            id: divider
            width: parent.width
            height: 1
            color: AeroColors.border
        }

        // Nadir panel (Arducam)
        AeroCameraPanel {
            id: nadirPanel
            width: parent.width
            height: parent.height - fpvPanel.height - divider.height
            cameraLabel: "NADIR"
            // Verified OAK-D Lite WFB ground stream: MPEG-TS/H.264 over UDP.
            source: "mpegts://0.0.0.0:5604"
            displayLabel: root.camera2Label
            expansionHost: root.expansionHost
            showBorder: false
            onLayoutRequested: function(state) { root.setCameraLayout(nadirPanel, state) }
            onDiagnosticRequested: function(diagnosticId) { root.diagnosticRequested(diagnosticId) }
        }
    }
}
