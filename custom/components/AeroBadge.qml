// AeroBadge.qml
// Small pill/badge for counts and status labels.
//
// Properties:
//   text       (string) — badge content
//   badgeStyle (string) — "default"|"critical"|"advisory"|"healthy"|"accent"

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property string text:       ""
    property string badgeStyle: "default"

    implicitWidth:  label.implicitWidth + AeroMetrics.gap * 2
    implicitHeight: 18

    // Minimum pill width
    readonly property int _minWidth: 28

    width: Math.max(implicitWidth, _minWidth)

    // ── Color resolvers ───────────────────────────────────────────────────────
    readonly property color _bgColor: {
        switch (root.badgeStyle) {
        case "critical": return AeroColors.criticalDim
        case "advisory": return AeroColors.surfaceHover   // amber tint via text
        case "healthy":  return Qt.rgba(
                             AeroColors.healthy.r,
                             AeroColors.healthy.g,
                             AeroColors.healthy.b, 0.12)
        case "accent":   return AeroColors.accentSubtle
        default:         return AeroColors.surfaceRaised
        }
    }

    readonly property color _borderColor: {
        switch (root.badgeStyle) {
        case "critical": return AeroColors.critical
        case "advisory": return AeroColors.advisory
        case "healthy":  return AeroColors.healthy
        case "accent":   return AeroColors.accent
        default:         return AeroColors.borderStrong
        }
    }

    readonly property color _textColor: {
        switch (root.badgeStyle) {
        case "critical": return AeroColors.critical
        case "advisory": return AeroColors.advisory
        case "healthy":  return AeroColors.healthy
        case "accent":   return AeroColors.accent
        default:         return AeroColors.textSecondary
        }
    }

    // ── Background pill ───────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius:       height / 2     // full pill
        color:        root._bgColor
        border.color: root._borderColor
        border.width: AeroMetrics.borderThin

        Behavior on color        { ColorAnimation { duration: AeroMotion.fast } }
        Behavior on border.color { ColorAnimation { duration: AeroMotion.fast } }
    }

    // ── Label ─────────────────────────────────────────────────────────────────
    Text {
        id: label
        anchors.centerIn: parent
        text:  root.text
        color: root._textColor
        font.family:    AeroTypography.family
        font.pixelSize: AeroTypography.caption   // 16px minimum
        font.weight:    AeroTypography.weightMedium

        Behavior on color { ColorAnimation { duration: AeroMotion.fast } }
    }
}
