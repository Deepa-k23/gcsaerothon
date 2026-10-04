import re

with open('custom/src/AeroNavRail.qml', 'r') as f:
    content = f.read()

content = content.replace('font.family: AeroMetrics.fontFamily', 'font.family: AeroTypography.uiFamily')

with open('custom/src/AeroNavRail.qml', 'w') as f:
    f.write(content)
