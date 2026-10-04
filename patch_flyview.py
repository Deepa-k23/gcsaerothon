import re

with open('/home/deepa/AeroTHON-GCS-V2/src/FlyView/FlyViewMap.qml', 'r') as f:
    content = f.read()

replacement = '''
    property var activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    function sendTelemetryToGodsEye() {
        if (activeVehicle && activeVehicle.coordinate.isValid) {
            var lat = activeVehicle.coordinate.latitude;
            var lon = activeVehicle.coordinate.longitude;
            var alt = activeVehicle.altitudeRelative.rawValue;
            var hdg = activeVehicle.heading.rawValue;
            if (!isNaN(lat) && !isNaN(lon)) {
                var script = "if (window.updateAeroTHONTelemetry) window.updateAeroTHONTelemetry({" +
                    "latitude: " + lat + ", " +
                    "longitude: " + lon + ", " +
                    "altitude: " + (isNaN(alt) ? 0 : alt) + ", " +
                    "heading: " + hdg + 
                "});";
                webEngineView.runJavaScript(script);
            }
        } else {
            var script = "if (window.updateAeroTHONTelemetry) window.updateAeroTHONTelemetry(null);"; // Disconnected
            webEngineView.runJavaScript(script);
        }
    }

    Connections {
        target: activeVehicle
        ignoreUnknownSignals: true
        function onCoordinateChanged() { sendTelemetryToGodsEye() }
        function onHeadingChanged() { sendTelemetryToGodsEye() }
    }

    Connections {
        target: QGroundControl.multiVehicleManager
        function onActiveVehicleChanged() { sendTelemetryToGodsEye() }
    }

    Timer {
        interval: 1000 // Fallback 1Hz
        running: true
        repeat: true
        onTriggered: {
            sendTelemetryToGodsEye()
        }
    }
'''

content = re.sub(r'Timer \{\s*interval: 250.*?onTriggered: \{.*?\}\s*\}', replacement.strip(), content, flags=re.DOTALL)

with open('/home/deepa/AeroTHON-GCS-V2/src/FlyView/FlyViewMap.qml', 'w') as f:
    f.write(content)
