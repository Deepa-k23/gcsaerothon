with open('custom/custom.qrc', 'r') as f:
    content = f.read()

content = content.replace('<file alias="QGroundControl/FlyView/AeroLeftPanel.qml">src/AeroLeftPanel.qml</file>',
                          '<file alias="QGroundControl/FlyView/AeroLeftPanel.qml">src/AeroLeftPanel.qml</file>\n        <file alias="QGroundControl/FlyView/AeroCompactTelemetryBox.qml">src/AeroCompactTelemetryBox.qml</file>')

with open('custom/custom.qrc', 'w') as f:
    f.write(content)
