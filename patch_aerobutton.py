import re

with open('/home/deepa/AeroTHON-GCS-V2/custom/components/AeroButton.qml', 'r') as f:
    content = f.read()

# Replace _bgColor
bg_old = '''    readonly property color _bgColor: {
        if (!enabled) return AeroColors.surfaceRaised
        if (buttonState === "active") {
            return buttonStyle === "ghost" ? AeroColors.accentSubtle : AeroColors.accent
        }
        if (buttonState === "critical") return AeroColors.criticalDim
        if (buttonState === "advisory") return AeroColors.surfaceHover
        // default / hover states resolved with hoverActive
        if (buttonStyle === "primary")   return hoverActive ? AeroColors.surfaceHover : AeroColors.surfaceRaised
        if (buttonStyle === "secondary") return hoverActive ? AeroColors.surfaceHover : "transparent"
        return "transparent"
    }'''

bg_new = '''    readonly property color _bgColor: {
        if (!enabled) return Qt.rgba(0.1, 0.1, 0.15, 0.4)
        if (buttonState === "active") return Qt.rgba(0.0, 0.6, 0.8, 0.4) // cyan translucent
        if (buttonState === "critical") return Qt.rgba(0.8, 0.2, 0.2, 0.4)
        if (buttonState === "advisory") return Qt.rgba(0.8, 0.6, 0.0, 0.4)
        return hoverActive ? Qt.rgba(0.1, 0.2, 0.35, 0.75) : Qt.rgba(0.05, 0.1, 0.2, 0.6)
    }'''
content = content.replace(bg_old, bg_new)

# Replace _borderColor
border_old = '''    readonly property color _borderColor: {
        if (!enabled) return AeroColors.borderStrong
        if (buttonState === "active")   return AeroColors.accent
        if (buttonState === "critical") return AeroColors.critical
        if (buttonState === "advisory") return AeroColors.advisory
        if (buttonStyle === "ghost")    return "transparent"
        return hoverActive ? AeroColors.accent : AeroColors.borderStrong
    }'''

border_new = '''    readonly property color _borderColor: {
        if (!enabled) return Qt.rgba(1, 1, 1, 0.1)
        if (buttonState === "active") return Qt.rgba(0.0, 1.0, 1.0, 0.5) // cyan
        if (buttonState === "critical") return Qt.rgba(1.0, 0.3, 0.3, 0.5)
        if (buttonState === "advisory") return Qt.rgba(1.0, 0.8, 0.2, 0.5)
        return hoverActive ? Qt.rgba(0.0, 1.0, 1.0, 0.4) : Qt.rgba(1, 1, 1, 0.15)
    }'''
content = content.replace(border_old, border_new)

# Replace _textColor
text_old = '''    readonly property color _textColor: {
        if (!enabled) return AeroColors.textMuted
        if (buttonState === "active" && buttonStyle !== "ghost") return AeroColors.background
        if (buttonState === "active")   return AeroColors.accent
        if (buttonState === "critical") return AeroColors.critical
        if (buttonState === "advisory") return AeroColors.advisory
        return hoverActive ? AeroColors.accent : AeroColors.textPrimary
    }'''

text_new = '''    readonly property color _textColor: {
        if (!enabled) return Qt.rgba(1, 1, 1, 0.4)
        if (buttonState === "active") return "#FFFFFF"
        if (buttonState === "critical") return "#FFCCCC"
        if (buttonState === "advisory") return "#FFEECC"
        return "#FFFFFF"
    }'''
content = content.replace(text_old, text_new)

with open('/home/deepa/AeroTHON-GCS-V2/custom/components/AeroButton.qml', 'w') as f:
    f.write(content)
