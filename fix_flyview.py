with open('/home/deepa/AeroTHON-GCS-V2/src/FlyView/FlyViewMap.qml', 'r') as f:
    content = f.read()

content = content.replace('''    Timer {
        interval: 1000 // Fallback 1Hz
        running: true
        repeat: true
        onTriggered: {
            sendTelemetryToGodsEye()
        }
    }
        }
    }''', '''    Timer {
        interval: 1000 // Fallback 1Hz
        running: true
        repeat: true
        onTriggered: {
            sendTelemetryToGodsEye()
        }
    }''')

with open('/home/deepa/AeroTHON-GCS-V2/src/FlyView/FlyViewMap.qml', 'w') as f:
    f.write(content)
