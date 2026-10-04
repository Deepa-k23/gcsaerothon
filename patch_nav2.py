import re

with open('custom/src/AeroNavRail.qml', 'r') as f:
    content = f.read()

content = content.replace('import QtQuick\n', 'import QtQuick\nimport QGroundControl.Controls\n')

with open('custom/src/AeroNavRail.qml', 'w') as f:
    f.write(content)
