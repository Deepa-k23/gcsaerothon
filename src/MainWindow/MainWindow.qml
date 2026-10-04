import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.PlanView
import QGroundControl.Toolbar
import AeroTHON 1.0

/// @brief Native QML top level window
/// All properties defined here are visible to all QML pages.
ApplicationWindow {
    id:         mainWindow
    visible:    true
    // The special casing for android prevents white bars from showing up on the edges of the screen with newer android versions
    flags:      Qt.Window | (ScreenTools.isAndroid ? Qt.ExpandedClientAreaHint | Qt.NoTitleBarBackgroundHint : 0)

    // Qt 6.9+ auto-sets ApplicationWindow padding to the display safe-area insets on mobile,
    // which insets our full-bleed content and leaves a blank strip along the screen edge.
    // QGC draws edge-to-edge and manages its own insets, so zero the padding.
    topPadding:    0
    bottomPadding: 0
    leftPadding:   0
    rightPadding:  0

    Component.onCompleted: {
        // Start the sequence of first run prompt(s)
        firstRunPromptManager.nextPrompt()
    }

    /// Saves main window position and size and re-opens it in the same position and size next time
    MainWindowSavedState {
        window: mainWindow
    }

    QtObject {
        id: firstRunPromptManager

        property var currentDialog:     null
        property var rgPromptIds:       QGroundControl.corePlugin.firstRunPromptsToShow()
        property int nextPromptIdIndex: 0

        function clearNextPromptSignal() {
            if (currentDialog) {
                currentDialog.closed.disconnect(nextPrompt)
            }
        }

        function nextPrompt() {
            if (nextPromptIdIndex < rgPromptIds.length) {
                var component = Qt.createComponent(QGroundControl.corePlugin.firstRunPromptResource(rgPromptIds[nextPromptIdIndex]));
                currentDialog = component.createObject(mainWindow)
                currentDialog.closed.connect(nextPrompt)
                currentDialog.open()
                nextPromptIdIndex++
            } else {
                currentDialog = null
                showPreFlightChecklistIfNeeded()
            }
        }
    }

    readonly property real      _topBottomMargins:          ScreenTools.defaultFontPixelHeight * 0.5
    property string             aeroActiveRoute:            "flight"

    //-------------------------------------------------------------------------
    //-- Global Scope Variables

    QtObject {
        id: globals

        readonly property var       activeVehicle:                  QGroundControl.multiVehicleManager.activeVehicle
        readonly property real      defaultTextHeight:              ScreenTools.defaultFontPixelHeight
        readonly property real      defaultTextWidth:               ScreenTools.defaultFontPixelWidth
        readonly property var       planMasterControllerFlyView:    flyView.planController
        readonly property var       guidedControllerFlyView:        flyView.guidedController

        // Number of QGCTextField's with validation errors. Used to prevent closing panels with validation errors.
        property int                validationErrorCount:           0

        // Set to a non-empty string to block navigation with a custom reason (e.g. during calibration)
        property string             navigationBlockedReason:        ""

        // Property to manage RemoteID quick access to settings page
        property bool               commingFromRIDIndicator:        false
    }

    /// Default color palette used throughout the UI
    QGCPalette { id: qgcPal; colorGroupEnabled: true }

    //-------------------------------------------------------------------------
    //-- Actions

    signal armVehicleRequest
    signal forceArmVehicleRequest
    signal disarmVehicleRequest
    signal vtolTransitionToFwdFlightRequest
    signal vtolTransitionToMRFlightRequest
    signal showPreFlightChecklistIfNeeded
    signal aeroPayloadRequest
    signal aeroEscapeRequest

    function aeroShortcutEditingText() {
        if (!mainWindow.activeFocusControl) {
            return false
        }
        var c = mainWindow.activeFocusControl
        if (c.readOnly === true) {
            return false
        }
        if (c.cursorPosition !== undefined || c.selectedText !== undefined) {
            return true
        }
        return false
    }

    function aeroShortcutUnavailable(actionName) {
        AeroAlertModel.raiseAlert("SHORTCUT:" + actionName, "INFO", "SYSTEM",
                                  actionName + " unavailable", "No active vehicle or unsupported flight mode")
    }

    function triggerAeroVehicleAction(actionId) {
        if (actionId === "payload") {
            aeroPayloadRequest()
            return
        }
        var vehicle = globals.activeVehicle
        if (!vehicle) {
            aeroShortcutUnavailable(actionId.toUpperCase())
            return
        }
        switch (actionId) {
        case "arm":
            vehicle.setArmed(true, true)
            break
        case "disarm":
            vehicle.setArmed(false, true)
            break
        case "rtl":
            vehicle.guidedModeRTL(false)
            break
        case "hold":
            vehicle.pauseVehicle()
            break
        case "land":
            vehicle.guidedModeLand()
            break
        case "takeoff":
            if (vehicle.supports && vehicle.supports.guidedTakeoffWithAltitude) {
                vehicle.guidedModeTakeoff(10.0)
            } else {
                vehicle.startTakeoff()
            }
            break
        case "pause":
            vehicle.pauseVehicle()
            break
        case "reboot":
            vehicle.rebootVehicle()
            break
        case "mission":
            AeroTHONManager.startNativeMission()
            break
        }
    }

    function triggerAeroFlightMode(requestedMode) {
        var vehicle = globals.activeVehicle
        if (!vehicle) {
            aeroShortcutUnavailable(requestedMode)
            return
        }
        var target = requestedMode.toUpperCase()
        var modes = vehicle.flightModes

        // 1. Direct case-insensitive match
        for (var i = 0; i < modes.length; ++i) {
            if (String(modes[i]).toUpperCase() === target) {
                vehicle.flightMode = modes[i]
                return
            }
        }

        // 2. Alias match across PX4 / ArduPilot
        var aliasMap = {
            "MANUAL": ["MANUAL"],
            "STABILIZED": ["STABILIZED", "STABILIZE"],
            "ACRO": ["ACRO"],
            "ALTITUDE": ["ALTITUDE", "ALTCTL", "ALT_HOLD"],
            "POSITION": ["POSITION", "POSCTL", "POSHOLD", "LOITER"],
            "MISSION": ["MISSION", "AUTO", "AUTO.MISSION", "AUTO (MISSION)"],
            "HOLD": ["HOLD", "LOITER", "AUTO.LOITER", "AUTO (LOITER)"],
            "RTL": ["RTL", "AUTO.RTL", "AUTO (RTL)", "SMART_RTL"],
            "LAND": ["LAND", "AUTO.LAND", "AUTO (LAND)"]
        }

        var aliases = aliasMap[target] || [target]
        for (var a = 0; a < aliases.length; ++a) {
            var alias = aliases[a].toUpperCase()
            for (var m = 0; m < modes.length; ++m) {
                var mUpper = String(modes[m]).toUpperCase()
                if (mUpper === alias || mUpper.indexOf(alias) !== -1) {
                    vehicle.flightMode = modes[m]
                    return
                }
            }
        }

        aeroShortcutUnavailable(requestedMode)
    }

    // ── Global Vehicle Control Shortcuts ──────────────────────────────────────
    Shortcut { sequence: "Ctrl+Shift+A"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("arm") }
    Shortcut { sequence: "Ctrl+Shift+D"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("disarm") }
    Shortcut { sequence: "Ctrl+Shift+R"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("rtl") }
    Shortcut { sequence: "Ctrl+R";       context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("rtl") }
    Shortcut { sequence: "Ctrl+Shift+L"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("land") }
    Shortcut { sequence: "Ctrl+L";       context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("land") }
    Shortcut { sequence: "Ctrl+Shift+P"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("payload") }
    Shortcut { sequence: "Ctrl+Shift+H"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("hold") }
    Shortcut { sequence: "Ctrl+H";       context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("hold") }
    Shortcut { sequence: "Ctrl+Shift+B"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("reboot") }
    Shortcut { sequence: "Ctrl+Shift+M"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroVehicleAction("mission") }

    // ── Flight Mode Shortcuts ──────────────────────────────────────────────────
    Shortcut { sequence: "Ctrl+1"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("MANUAL") }
    Shortcut { sequence: "Ctrl+M"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("MANUAL") }
    Shortcut { sequence: "Ctrl+2"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("STABILIZED") }
    Shortcut { sequence: "Ctrl+3"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("ACRO") }
    Shortcut { sequence: "Ctrl+5"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("ALTITUDE") }
    Shortcut { sequence: "Ctrl+6"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("POSITION") }
    Shortcut { sequence: "Ctrl+P"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("POSITION") }
    Shortcut { sequence: "Ctrl+7"; context: Qt.ApplicationShortcut; enabled: !mainWindow.aeroShortcutEditingText(); onActivated: mainWindow.triggerAeroFlightMode("MISSION") }

    // ── Global Overlay & Navigation Shortcuts ─────────────────────────────────
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; onActivated: mainWindow.aeroEscapeRequest() }

    //-------------------------------------------------------------------------
    //-- Global Scope Functions

    // This function is used to prevent view switching if there are validation errors
    function allowViewSwitch(previousValidationErrorCount = 0, showErrorOnDisallow = true) {
        // Check for explicit navigation block (e.g. calibration in progress)
        if (globals.navigationBlockedReason !== "") {
            if (showErrorOnDisallow) {
                validationErrorToast.text = globals.navigationBlockedReason
                if (validationErrorToast.visible) {
                    validationErrorToast.close()
                }
                validationErrorToast.open()
            }
            return false
        }
        // Run validation on active focus control to ensure it is valid before switching views
        if (mainWindow.activeFocusControl instanceof FactTextField) {
            mainWindow.activeFocusControl._onEditingFinished()
        }
        var allowed = globals.validationErrorCount <= previousValidationErrorCount
        if (!allowed && showErrorOnDisallow) {
            validationErrorToast.text = qsTr("Please correct the invalid value before continuing")
            if (validationErrorToast.visible) {
                validationErrorToast.close()
            }
            validationErrorToast.open()
        }
        return allowed
    }

    function showPlanView() {
        aeroActiveRoute = "plan"
        flyView.visible = false
        planView.visible = true
        geoView.visible = false
        toolDrawer.visible = false
    }

    function showFlyView() {
        aeroActiveRoute = "flight"
        flyView.visible = true
        planView.visible = false
        geoView.visible = false
        toolDrawer.visible = false
    }

    function showGeoView() {
        flyView.visible = false
        planView.visible = false
        geoView.visible = true
        toolDrawer.visible = false
    }

    function showTool(toolTitle, toolSource, toolIcon) {
        toolDrawer.backIcon     = flyView.visible ? "/qmlimages/PaperPlane.svg" : (geoView.visible ? "/InstrumentValueIcons/globe.svg" : "/qmlimages/Plan.svg")
        toolDrawer.toolTitle    = toolTitle
        toolDrawer.toolSource   = toolSource
        toolDrawer.toolIcon     = toolIcon
        toolDrawer.visible      = true
    }

    function showAnalyzeTool() {
        aeroActiveRoute = "logs"
        showTool(qsTr("Analyze Tools"), "qrc:/qml/QGroundControl/AnalyzeView/AnalyzeView.qml", "/qmlimages/Analyze.svg")
    }

    function showVehicleConfig() {
        aeroActiveRoute = "vehicle"
        showTool(qsTr("Vehicle Configuration"), "qrc:/qml/QGroundControl/VehicleSetup/VehicleConfigView.qml", "/qmlimages/Gears.svg")
    }

    function showVehicleConfigParametersPage() {
        showVehicleConfig()
        aeroActiveRoute = "params"
        toolDrawerLoader.item.showParametersPanel()
    }

    function showKnownVehicleComponentConfigPage(knownVehicleComponent) {
        showVehicleConfig()
        let vehicleComponent = globals.activeVehicle.autopilotPlugin.findKnownVehicleComponent(knownVehicleComponent)
        if (vehicleComponent) {
            toolDrawerLoader.item.showVehicleComponentPanel(vehicleComponent)
        }
    }

    function showSettingsTool(settingsPage = "") {
        aeroActiveRoute = "settings"
        showTool(qsTr("Application Settings"), "qrc:/qml/QGroundControl/Controls/AppSettings.qml", "/res/QGCLogoWhite")
        if (settingsPage !== "") {
            toolDrawerLoader.item.showSettingsPage(settingsPage)
        }
    }

    function navigateAeroRoute(routeId) {
        if (!allowViewSwitch()) {
            return
        }
        switch (routeId) {
        case "flight":
            showFlyView()
            break
        case "plan":
            showPlanView()
            break
        case "mission":
            showFlyView()
            aeroActiveRoute = "mission"
            break
        case "vehicle":
            showVehicleConfig()
            break
        case "params":
            showVehicleConfigParametersPage()
            break
        case "logs":
            showAnalyzeTool()
            break
        case "systems":
            aeroActiveRoute = "systems"
            showTool(qsTr("AeroTHON Systems"), "qrc:/qml/QGroundControl/FlyView/AeroSystemsScreen.qml", "/qmlimages/Analyze.svg")
            break
        case "px4doctor":
            aeroActiveRoute = "px4doctor"
            showTool(qsTr("PX4 Doctor"), "qrc:/qml/QGroundControl/FlyView/AeroPX4Doctor.qml", "/qmlimages/Analyze.svg")
            break
        case "preflight":
            aeroActiveRoute = "preflight"
            showTool(qsTr("Pre-Flight Check"), "qrc:/qml/QGroundControl/FlyView/AeroPreflightPanel.qml", "/check.svg")
            break
        case "settings":
            showSettingsTool()
            break
        }
    }

    function showAeroDiagnostic(diagnosticId) {
        aeroActiveRoute = "systems"
        showTool(qsTr("AeroTHON Systems"), "qrc:/qml/QGroundControl/FlyView/AeroSystemsScreen.qml", "/qmlimages/Analyze.svg")
    }

    //-------------------------------------------------------------------------
    //-- Global simple message dialog

    function _showMessageDialogWorker(owner, dialogTitle, dialogText, buttons = Dialog.Ok, acceptFunction = null, closeFunction = null, bypassNavigationCheck = false) {
        let dialog = simpleMessageDialogComponent.createObject(owner, { title: dialogTitle, text: dialogText, buttons: buttons, acceptFunction: acceptFunction, closeFunction: closeFunction, bypassNavigationCheck: bypassNavigationCheck })
        dialog.open()
    }

    // This variant is only meant to be called by QGCApplication
    function _showMessageDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle, dialogText)
    }

    // This variant is only meant to be called by QGCApplication. Ok reboots the active vehicle.
    function _showRebootVehicleDialog(dialogTitle, dialogText) {
        _showMessageDialogWorker(mainWindow, dialogTitle,
                                 dialogText + " " + qsTr("Click Ok to reboot the vehicle now."),
                                 Dialog.Ok | Dialog.Cancel,
                                 function() {
                                     const activeVehicle = QGroundControl.multiVehicleManager.activeVehicle
                                     if (activeVehicle) {
                                         activeVehicle.rebootVehicle()
                                     }
                                 })
    }

    Connections {
        target: QGroundControl

        function onShowMessageDialogRequested(owner, title, text, buttons, acceptFunction, closeFunction) {
            _showMessageDialogWorker(owner, title, text, buttons, acceptFunction, closeFunction)
        }
    }

    Component {
        id: simpleMessageDialogComponent

        QGCSimpleMessageDialog {
        }
    }

    property bool _forceClose: false
    property bool suppressCriticalVehicleMessages: false

    function finishCloseProcess() {
        _forceClose = true
        // For some reason on the Qml side Qt doesn't automatically disconnect a signal when an object is destroyed.
        // So we have to do it ourselves otherwise the signal flows through on app shutdown to an object which no longer exists.
        firstRunPromptManager.clearNextPromptSignal()
        QGroundControl.linkManager.shutdown()
        QGroundControl.videoManager.stopVideo();
        mainWindow.close()
    }

    // Check for things which should prevent the app from closing
    //  Returns true if it is OK to close
    readonly property int _skipUnsavedMissionCheckMask: 0x01
    readonly property int _skipPendingParameterWritesCheckMask: 0x02
    readonly property int _skipActiveConnectionsCheckMask: 0x04
    property int _closeChecksToSkip: 0
    property bool _reentrantCloseGuard: false
    function performCloseChecks() {
        if (!(_closeChecksToSkip & _skipUnsavedMissionCheckMask) && !checkForUnsavedMission()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipPendingParameterWritesCheckMask) && !checkForPendingParameterWrites()) {
            return false
        }
        if (!(_closeChecksToSkip & _skipActiveConnectionsCheckMask) && !checkForActiveConnections()) {
            return false
        }
        finishCloseProcess()
        return true
    }

    function checkForUnsavedMission() {
        // Only warn when edits are neither saved to disk nor uploaded to the vehicle.
        // If either happened the edits are recoverable, so closing loses nothing.
        // With no active vehicle an upload can't have happened, so treat the plan as
        // not uploaded regardless of dirtyForUpload.
        if (planView._planMasterController.dirtyForSave &&
                (planView._planMasterController.dirtyForUpload || !QGroundControl.multiVehicleManager.activeVehicle)) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Unsaved Mission"),
                              qsTr("You have a mission edit in progress which has not been saved/uploaded. If you close you will lose changes. Are you sure you want to close?"),
                              Dialog.Yes | Dialog.No,
                              function() { accepted = true; _closeChecksToSkip |= _skipUnsavedMissionCheckMask; performCloseChecks() },
                              function() { if (!accepted) _reentrantCloseGuard = false },
                              true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    function checkForPendingParameterWrites() {
        for (var index=0; index<QGroundControl.multiVehicleManager.vehicles.count; index++) {
            if (QGroundControl.multiVehicleManager.vehicles.get(index).parameterManager.pendingWrites) {
                let accepted = false
                _reentrantCloseGuard = true
                _showMessageDialogWorker(mainWindow, qsTr("Pending Parameter Updates"),
                    qsTr("You have pending parameter updates to a vehicle. If you close you will lose changes. Are you sure you want to close?"),
                    Dialog.Yes | Dialog.No,
                    function() { accepted = true; _closeChecksToSkip |= _skipPendingParameterWritesCheckMask; performCloseChecks() },
                    function() { if (!accepted) _reentrantCloseGuard = false },
                    true /* bypassNavigationCheck */)
                return false
            }
        }
        return true
    }

    function checkForActiveConnections() {
        if (QGroundControl.multiVehicleManager.activeVehicle) {
            let accepted = false
            _reentrantCloseGuard = true
            _showMessageDialogWorker(mainWindow, qsTr("Active Vehicle Connections"),
                qsTr("There are still active connections to vehicles. Are you sure you want to exit?"),
                Dialog.Yes | Dialog.No,
                function() { accepted = true; _closeChecksToSkip |= _skipActiveConnectionsCheckMask; performCloseChecks() },
                function() { if (!accepted) _reentrantCloseGuard = false },
                true /* bypassNavigationCheck */)
            return false
        } else {
            return true
        }
    }

    onClosing: (close) => {
        if (!_forceClose) {
            if (_reentrantCloseGuard) {
                close.accepted = false
                return
            }
            _closeChecksToSkip = 0
            close.accepted = performCloseChecks()
        }
    }

    background: Rectangle {
        anchors.fill:   parent
        color:          QGroundControl.globalPalette.window
    }

    FlyView {
        id:                     flyView
        objectName:             "mainView_fly"
        anchors.fill:           parent
        anchors.topMargin:      aeroShell.item ? aeroShell.item.contentTopInset : 0
        anchors.leftMargin:     aeroShell.item ? aeroShell.item.navRailWidth : 52
    }

    PlanView {
        id:             planView
        objectName:     "mainView_plan"
        anchors.fill:   parent
        anchors.topMargin:  aeroShell.item ? aeroShell.item.contentTopInset : 0
        anchors.leftMargin: aeroShell.item ? aeroShell.item.navRailWidth : 52
        visible:        false
    }

    FlyViewGeo {
        id:             geoView
        objectName:     "mainView_geo"
        anchors.fill:   parent
        anchors.topMargin:  aeroShell.item ? aeroShell.item.contentTopInset : 0
        anchors.leftMargin: aeroShell.item ? aeroShell.item.navRailWidth : 52
        visible:        false
    }

    footer: LogReplayStatusBar {
        visible: QGroundControl.settingsManager.flyViewSettings.showLogReplayStatusBar.rawValue
    }

    MessageDialog {
        id:                 showTouchAreasNotification
        title:              qsTr("Debug Touch Areas")
        text:               qsTr("Touch Area display toggled")
        buttons:            MessageDialog.Ok
    }

    MessageDialog {
        id:                 advancedModeOnConfirmation
        title:              qsTr("Advanced Mode")
        text:               QGroundControl.corePlugin.showAdvancedUIMessage
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = true
            }
        }
    }

    MessageDialog {
        id:                 advancedModeOffConfirmation
        title:              qsTr("Advanced Mode")
        text:               qsTr("Turn off Advanced Mode?")
        buttons:            MessageDialog.Yes | MessageDialog.No
        onButtonClicked: function (button, role) {
            if (button === MessageDialog.Yes) {
                QGroundControl.corePlugin.showAdvancedUI = false
            }
        }
    }

    function showToolSelectDialog() {
        if (mainWindow.allowViewSwitch()) {
            mainWindow.showIndicatorDrawer(toolSelectComponent, null)
        }
    }

    // Toast notification shown when a view switch is blocked by a validation error
    ToolTip {
        id:             validationErrorToast
        x:              (mainWindow.width - width) / 2
        y:              mainWindow.height - height - ScreenTools.defaultFontPixelHeight * 3
        timeout:        3000
        closePolicy:    Popup.NoAutoClose
        text:           qsTr("Please correct the invalid value before continuing")

        background: Rectangle {
            color:  qgcPal.alertBackground
            radius: ScreenTools.defaultFontPixelWidth / 2
        }

        contentItem: QGCLabel {
            text:   validationErrorToast.text
            color:  qgcPal.alertText
        }
    }

    Component {
        id: toolSelectComponent

        SelectViewDropdown {
        }
    }

    Rectangle {
        id:             toolDrawer
        objectName:     "mainView_toolDrawer"
        anchors.fill:   parent
        anchors.topMargin:  aeroShell.item ? aeroShell.item.contentTopInset : 0
        anchors.leftMargin: aeroShell.item ? aeroShell.item.navRailWidth : 52
        visible:        false
        color:          qgcPal.window

        property var backIcon
        property string toolTitle
        property alias toolSource:  toolDrawerLoader.source
        property var toolIcon

        onVisibleChanged: {
            if (!toolDrawer.visible) {
                toolDrawerLoader.source = ""
            }
        }

        // This need to block click event leakage to underlying map.
        DeadMouseArea {
            anchors.fill: parent
        }

        Loader {
            id:             toolDrawerLoader
            anchors.fill:   parent
        }
    }

    Loader {
        id: aeroShell
        anchors.fill: parent
        source: "qrc:/qml/QGroundControl/FlyView/AeroGlobalShell.qml"
        z: QGroundControl.zOrderTopMost + 1
        onLoaded: item.activeRoute = Qt.binding(function() { return mainWindow.aeroActiveRoute })
    }

    //-------------------------------------------------------------------------
    //-- Critical Vehicle Message Popup

    function showCriticalVehicleMessage(message) {
        if (suppressCriticalVehicleMessages) {
            return
        }
        if (criticalVehicleMessagePopup.visible || QGroundControl.videoManager.fullScreen) {
            // We received additional warning message while an older warning message was still displayed.
            // When the user close the older one drop the message indicator tool so they can see the rest of them.
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = true
        } else {
            criticalVehicleMessagePopup.criticalVehicleMessage      = message
            criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false
            criticalVehicleMessagePopup.open()
        }
    }

    Popup {
        id:                 criticalVehicleMessagePopup
        y:                  ScreenTools.toolbarHeight + ScreenTools.defaultFontPixelHeight
        x:                  Math.round((mainWindow.width - width) * 0.5)
        width:              mainWindow.width  * 0.55
        height:             criticalVehicleMessageText.contentHeight + ScreenTools.defaultFontPixelHeight * 2
        modal:              false
        focus:              true

        property alias  criticalVehicleMessage:             criticalVehicleMessageText.text
        property bool   additionalCriticalMessagesReceived: false

        background: Rectangle {
            anchors.fill:   parent
            color:          qgcPal.alertBackground
            radius:         ScreenTools.defaultFontPixelHeight * 0.5
            border.color:   qgcPal.alertBorder
            border.width:   2

            Rectangle {
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.top:                parent.top
                anchors.topMargin:          -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      vehicleWarningLabel.contentWidth + _margins
                height:                     vehicleWarningLabel.contentHeight + _margins

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 vehicleWarningLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Vehicle Error")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }

            Rectangle {
                id:                         additionalErrorsIndicator
                anchors.horizontalCenter:   parent.horizontalCenter
                anchors.bottom:             parent.bottom
                anchors.bottomMargin:       -(height / 2)
                color:                      qgcPal.alertBackground
                radius:                     ScreenTools.defaultFontPixelHeight * 0.25
                border.color:               qgcPal.alertBorder
                border.width:               1
                width:                      additionalErrorsLabel.contentWidth + _margins
                height:                     additionalErrorsLabel.contentHeight + _margins
                visible:                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived

                property real _margins: ScreenTools.defaultFontPixelHeight * 0.25

                QGCLabel {
                    id:                 additionalErrorsLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Additional errors received")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.alertText
                }
            }
        }

        QGCLabel {
            id:                 criticalVehicleMessageText
            width:              criticalVehicleMessagePopup.width - ScreenTools.defaultFontPixelHeight
            anchors.centerIn:   parent
            wrapMode:           Text.WordWrap
            color:              qgcPal.alertText
            textFormat:         TextEdit.RichText
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                criticalVehicleMessagePopup.close()
                if (criticalVehicleMessagePopup.additionalCriticalMessagesReceived) {
                    criticalVehicleMessagePopup.additionalCriticalMessagesReceived = false;
                    flyView.dropMainStatusIndicatorTool();
                } else if (QGroundControl.multiVehicleManager.activeVehicle) {
                    QGroundControl.multiVehicleManager.activeVehicle.resetErrorLevelMessages();
                }
            }
        }
    }

    //-------------------------------------------------------------------------
    //-- Indicator Drawer

    function showIndicatorDrawer(drawerComponent, indicatorItem) {
        indicatorDrawer.sourceComponent = drawerComponent
        indicatorDrawer.indicatorItem = indicatorItem
        indicatorDrawer.open()
    }

    function closeIndicatorDrawer() {
        indicatorDrawer.close()
    }

    Popup {
        id:             indicatorDrawer
        x:              calcXPosition()
        y:              ScreenTools.toolbarHeight + _margins
        leftInset:      0
        rightInset:     0
        topInset:       0
        bottomInset:    0
        padding:        _margins * 2
        visible:        false
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var sourceComponent
        property var indicatorItem

        property bool _expanded:    false
        property real _margins:     ScreenTools.defaultFontPixelHeight / 4

        function calcXPosition() {
            if (indicatorItem) {
                var xCenter = indicatorItem.mapToItem(mainWindow.contentItem, indicatorItem.width / 2, 0).x
                return Math.max(_margins, Math.min(xCenter - (contentItem.implicitWidth / 2), mainWindow.contentItem.width - contentItem.implicitWidth - _margins - (indicatorDrawer.padding * 2) - (ScreenTools.defaultFontPixelHeight / 2)))
            } else {
                return _margins
            }
        }

        onOpened: {
            _expanded                               = false;
            indicatorDrawerLoader.sourceComponent   = indicatorDrawer.sourceComponent
        }
        onClosed: {
            _expanded                               = false
            indicatorItem                           = undefined
            indicatorDrawerLoader.sourceComponent   = undefined
        }

        background: Item {
            Rectangle {
                id:             backgroundRect
                anchors.fill:   parent
                color:          QGroundControl.globalPalette.window
                radius:         indicatorDrawer._margins
                opacity:        0.85
            }

            Rectangle {
                objectName:                 "indicatorDrawerExpandButton"
                anchors.horizontalCenter:   backgroundRect.right
                anchors.verticalCenter:     backgroundRect.top
                width:                      ScreenTools.largeFontPixelHeight
                height:                     width
                radius:                     width / 2
                color:                      QGroundControl.globalPalette.button
                border.color:               QGroundControl.globalPalette.buttonText
                visible:                    indicatorDrawerLoader.item && indicatorDrawerLoader.item._showExpand && !indicatorDrawer._expanded

                QGCLabel {
                    anchors.centerIn:   parent
                    text:               ">"
                    color:              QGroundControl.globalPalette.buttonText
                }

                QGCMouseArea {
                    fillItem: parent
                    onClicked: indicatorDrawer._expanded = true
                }
            }
        }

        contentItem: QGCFlickable {
            id:             indicatorDrawerLoaderFlickable
            implicitWidth:  Math.min(mainWindow.contentItem.width - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.width)
            implicitHeight: Math.min(mainWindow.contentItem.height - ScreenTools.toolbarHeight - (2 * indicatorDrawer._margins) - (indicatorDrawer.padding * 2), indicatorDrawerLoader.height)
            contentWidth:   indicatorDrawerLoader.width
            contentHeight:  indicatorDrawerLoader.height

            Loader {
                id:         indicatorDrawerLoader
                objectName: "indicatorDrawerLoader"

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "expanded"
                    value:      indicatorDrawer._expanded
                }

                Binding {
                    target:     indicatorDrawerLoader.item
                    property:   "drawer"
                    value:      indicatorDrawer
                }
            }
        }
    }

    // Analyze page items (both in-panel and popped-out windows) are created with mainWindow as their
    // QObject parent so their lifetime is not tied to AnalyzeView. This lets a popped-out window
    // survive AnalyzeView being unloaded from the tool drawer.

    // Tracks the analyze page item currently shown inside AnalyzeView's panel (not popped out).
    // null when no page is loaded or the item has been handed off to a popup window.
    property var _inPanelAnalyzePage: null

    // Called by AnalyzeView.Component.onDestruction to destroy the in-panel item while
    // panelContainer is still alive.
    function destroyInPanelAnalyzePage() {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
    }

    // Called by AnalyzeView to create an analyze page item owned by mainWindow.
    // The caller sets the visual parent to panelContainer after creation.
    function createAnalyzePage(source) {
        if (_inPanelAnalyzePage) {
            _inPanelAnalyzePage.destroy()
            _inPanelAnalyzePage = null
        }
        var component = Qt.createComponent(source)
        if (component.status !== Component.Ready) {
            console.warn("createAnalyzePage failed source:", source, "errorString:", component.errorString())
            return null
        }
        _inPanelAnalyzePage = component.createObject(mainWindow)
        return _inPanelAnalyzePage
    }

    // Called by AnalyzeView when the in-panel item is handed off to a popup window.
    // Clears _inPanelAnalyzePage so destroyInPanelAnalyzePage() does not destroy it
    // when AnalyzeView is torn down.
    function analyzePageMovedToPopup() {
        _inPanelAnalyzePage = null
    }

    function createWindowedAnalyzePage(title, source, requiresVehicle, existingItem) {
        var windowedPage = windowedAnalyzePage.createObject(mainWindow)
        windowedPage.title = title
        windowedPage.requiresVehicle = requiresVehicle
        if (existingItem) {
            windowedPage.adoptItem(existingItem)
        } else {
            windowedPage.source = source
        }
        windowedPage.visible = true
    }

    Component {
        id: windowedAnalyzePage

        Window {
            width:      ScreenTools.defaultFontPixelWidth  * 100
            height:     ScreenTools.defaultFontPixelHeight * 40
            visible:    false

            property alias source: loader.source
            property bool requiresVehicle: false

            function adoptItem(item) {
                loader.visible = false
                loader.source = ""
                item.parent = contentRect
                item.anchors.fill = contentRect
                item.popped = true
                item.visible = true
            }

            Connections {
                target: QGroundControl.multiVehicleManager
                function onActiveVehicleChanged() {
                    if (requiresVehicle) {
                        close()
                    }
                }
            }

            Rectangle {
                id:             contentRect
                color:          QGroundControl.globalPalette.window
                anchors.fill:   parent

                Loader {
                    id:             loader
                    anchors.fill:   parent
                    onLoaded:       item.popped = true
                }
            }

            onClosing: {
                visible = false
                // Destroy any reparented children (not owned by loader)
                for (var i = contentRect.children.length - 1; i >= 0; i--) {
                    var child = contentRect.children[i]
                    if (child !== loader) {
                        child.destroy()
                    }
                }
                source = ""
                Qt.callLater(destroy)
            }
        }
    }
}
