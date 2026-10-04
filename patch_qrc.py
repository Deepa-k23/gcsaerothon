with open('custom/custom.qrc', 'r') as f:
    content = f.read()

if 'AeroCompactTelemetryBox.qml' not in content:
    content = content.replace('<file alias="AeroLeftPanel.qml">src/AeroLeftPanel.qml</file>',
                              '<file alias="AeroLeftPanel.qml">src/AeroLeftPanel.qml</file>\n        <file alias="AeroCompactTelemetryBox.qml">src/AeroCompactTelemetryBox.qml</file>')
    with open('custom/custom.qrc', 'w') as f:
        f.write(content)
