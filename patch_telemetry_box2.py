with open('custom/src/AeroCompactTelemetryBox.qml', 'r') as f:
    content = f.read()

content = content.replace('AeroMetrics.fontFamily', 'AeroTypography.dataFamily')

with open('custom/src/AeroCompactTelemetryBox.qml', 'w') as f:
    f.write(content)
