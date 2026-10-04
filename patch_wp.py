import re

with open('custom/src/AeroCompactTelemetryBox.qml', 'r') as f:
    content = f.read()

content = content.replace('vehicle.wpDistance.rawValue', 'vehicle.distanceToNextWP.rawValue')

with open('custom/src/AeroCompactTelemetryBox.qml', 'w') as f:
    f.write(content)
