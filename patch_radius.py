import re

with open('custom/src/AeroCompactTelemetryBox.qml', 'r') as f:
    content = f.read()

content = content.replace('radius: AeroMetrics.radiusMedium', 'radius: AeroMetrics.radiusPanel')

with open('custom/src/AeroCompactTelemetryBox.qml', 'w') as f:
    f.write(content)
