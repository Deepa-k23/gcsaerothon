with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroNavRail.qml', 'r') as f:
    content = f.read()

content = content.replace("id: nav\n        z: nav._hovered ? 100 : 1Label", "id: navLabel")

with open('/home/deepa/AeroTHON-GCS-V2/custom/src/AeroNavRail.qml', 'w') as f:
    f.write(content)
