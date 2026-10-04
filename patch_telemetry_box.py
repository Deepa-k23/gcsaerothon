with open('custom/src/AeroCompactTelemetryBox.qml', 'r') as f:
    content = f.read()

content = content.replace('color: AeroColors.surfaceDark', 'color: AeroColors.surface')
content = content.replace('border.color: AeroColors.borderLight', 'border.color: AeroColors.border')

with open('custom/src/AeroCompactTelemetryBox.qml', 'w') as f:
    f.write(content)
