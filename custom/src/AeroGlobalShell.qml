import QtQuick
import QGroundControl
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    readonly property real topBarHeight: AeroMetrics.topBarHeight
    readonly property real contentTopInset: activeRoute === "flight" ? topBarHeight : 0
    readonly property real navRailWidth: AeroMetrics.navRailWidth
    property string activeRoute: "flight"

    // Load the bundled "JetBrains Mono" face app-wide before any telemetry renders.
    AeroFonts { }

    AeroTopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        visible: root.activeRoute === "flight"
        vehicle: QGroundControl.multiVehicleManager.activeVehicle
        hideLogo: startupOverlay.isPlaying
        onDiagnosticRequested: function(diagnosticId) { mainWindow.showAeroDiagnostic(diagnosticId) }
    }

    AeroNavRail {
        anchors.left: parent.left
        anchors.top: root.activeRoute === "flight" ? topBar.bottom : parent.top
        anchors.bottom: parent.bottom
        activeScreen: root.activeRoute
        onScreenRequested: function(routeId) { mainWindow.navigateAeroRoute(routeId) }
    }

    AeroStartupOverlay {
        id: startupOverlay
        z: 999
    }
}
