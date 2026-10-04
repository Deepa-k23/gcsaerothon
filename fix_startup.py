path = '/home/deepa/AeroTHON-GCS-V2/custom/src/AeroStartupOverlay.qml'
with open(path, 'r') as f:
    content = f.read()

# Change logo source
content = content.replace('"qrc:/Custom/AeroTHON/assets/aerokle_logo_dark.png"', '"qrc:/Custom/AeroTHON/assets/gcslogo.png"')

# Change dimensions
content = content.replace('readonly property real finalW: root.width < 1500 ? 42 : 54', 'readonly property real finalW: (root.width < 1500 ? 42 : 54) * 1.30')
content = content.replace('readonly property real finalH: 28', 'readonly property real finalH: 28 * 1.30')
content = content.replace('readonly property real centerW: 240', 'readonly property real centerW: 240 * 1.30')
content = content.replace('readonly property real centerH: 124', 'readonly property real centerH: 124 * 1.30')

with open(path, 'w') as f:
    f.write(content)
