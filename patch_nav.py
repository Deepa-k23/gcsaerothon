import re

with open('custom/src/AeroNavRail.qml', 'r') as f:
    content = f.read()

# Replace Image and MultiEffect with QGCColoredImage
old = r'''            Image \{
                id: _src
                source: nav\.navData \? nav\.navData\.iconSource : ""
                width: 22; height: 22; sourceSize\.width: 22; sourceSize\.height: 22
                smooth: true; antialiasing: true; fillMode: Image\.PreserveAspectFit
                visible: false
            \}

            MultiEffect \{
                id: _icon
                source: _src
                x: floatingBg\._iconX
                y: \(floatingBg\.height - 22\) / 2
                width: 22; height: 22
                layer\.enabled: true
                colorization: 1\.0
                colorizationColor: \{
                    if \(nav\.isActive\) return AeroColors\.accent
                    return "#F4F7FA"  // white/off-white per spec §8
                \}
                opacity: nav\.isActive \? 1\.0 : \(nav\._hovered \? 1\.0 : 0\.9\)

                Behavior on colorizationColor \{
                    ColorAnimation \{
                        duration: AeroMotion\.fast
                        easing\.type: AeroMotion\.easingStandard
                    \}
                \}
            \}'''

new = '''            QGCColoredImage {
                id: _icon
                source: nav.navData ? nav.navData.iconSource : ""
                x: floatingBg._iconX
                y: (floatingBg.height - 22) / 2
                width: 22; height: 22
                sourceSize.width: 22; sourceSize.height: 22
                fillMode: Image.PreserveAspectFit
                color: nav.isActive ? AeroColors.accent : "#F4F7FA"
                opacity: nav.isActive ? 1.0 : (nav._hovered ? 1.0 : 0.9)
                Behavior on color {
                    ColorAnimation {
                        duration: AeroMotion.fast
                        easing.type: AeroMotion.easingStandard
                    }
                }
            }'''

content = re.sub(old, new, content)

with open('custom/src/AeroNavRail.qml', 'w') as f:
    f.write(content)

