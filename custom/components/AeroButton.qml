// AeroButton.qml
// Technical action button with full state machine and style variants.
//
// Properties:
//   label       (string)   — button text
//   iconText    (string)   — optional icon character / unicode
//   buttonState (string)   — "default"|"active"|"advisory"|"critical"|"disabled"
//   buttonStyle (string)   — "primary"|"secondary"|"ghost"
//
import QtQuick
import QtQuick.Controls.Basic
import "qrc:/Custom/AeroTHON/theme"

AbstractButton {
    id: root

    // ── Public API ────────────────────────────────────────────────────────────
    property string label:       ""
    property string iconText:    ""
    property string buttonState: "default"   // "default"|"active"|"advisory"|"critical"|"disabled"
    property string buttonStyle: "primary"   // "primary"|"secondary"|"ghost"

    // ── Geometry ──────────────────────────────────────────────────────────────
    implicitHeight: AeroMetrics.quickActionHeight
    implicitWidth:  Math.max(72, contentRow.implicitWidth + AeroMetrics.gapLarge * 2)

    enabled: buttonState !== "disabled"

    // ── Derived color tokens ──────────────────────────────────────────────────
    readonly property color _bgColor: {
        if (!enabled) return Qt.rgba(0.1, 0.1, 0.15, 0.4)
        if (buttonState === "active") return Qt.rgba(0.0, 0.6, 0.8, 0.4) // cyan translucent
        if (buttonState === "critical") return Qt.rgba(0.8, 0.2, 0.2, 0.4)
        if (buttonState === "advisory") return Qt.rgba(0.8, 0.6, 0.0, 0.4)
        return hoverActive ? Qt.rgba(0.1, 0.2, 0.35, 0.75) : Qt.rgba(0.05, 0.1, 0.2, 0.6)
    }

    readonly property color _borderColor: {
        if (!enabled) return Qt.rgba(1, 1, 1, 0.1)
        if (buttonState === "active") return Qt.rgba(0.0, 1.0, 1.0, 0.5) // cyan
        if (buttonState === "critical") return Qt.rgba(1.0, 0.3, 0.3, 0.5)
        if (buttonState === "advisory") return Qt.rgba(1.0, 0.8, 0.2, 0.5)
        return hoverActive ? Qt.rgba(0.0, 1.0, 1.0, 0.4) : Qt.rgba(1, 1, 1, 0.15)
    }

    readonly property color _textColor: {
        if (!enabled) return Qt.rgba(1, 1, 1, 0.4)
        if (buttonState === "active") return "#FFFFFF"
        if (buttonState === "critical") return "#FFCCCC"
        if (buttonState === "advisory") return "#FFEECC"
        return "#FFFFFF"
    }

    // ── Hover/press state from AbstractButton ─────────────────────────────────
    readonly property bool hoverActive: hovered && buttonState === "default"

    // ── Background ────────────────────────────────────────────────────────────
    background: Rectangle {
        id: bg
        radius: AeroMetrics.radiusControl
        color:  root._bgColor
        border.color: root._borderColor
        border.width: AeroMetrics.borderThin

        Behavior on color        { ColorAnimation { duration: AeroMotion.fast; easing.type: AeroMotion.easingStandard } }
        Behavior on border.color { ColorAnimation { duration: AeroMotion.fast; easing.type: AeroMotion.easingStandard } }

        // Pressed overlay
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: AeroColors.accent
            opacity: root.pressed ? 0.15 : 0.0
            Behavior on opacity { NumberAnimation { duration: AeroMotion.micro } }
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────
    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: (root.iconText !== "" && root.label !== "") ? AeroMetrics.gapSmall : 0
        leftPadding: AeroMetrics.gapLarge
        rightPadding: AeroMetrics.gapLarge

        // Icon character
        Text {
            id: iconItem
            visible: root.iconText !== ""
            text: root.iconText
            color: root._textColor
            font.family: AeroTypography.family
            font.pixelSize: AeroTypography.body
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: AeroMotion.fast } }
        }

        // Label
        Text {
            id: labelItem
            visible: root.label !== ""
            text: root.label
            color: root._textColor
            font.family: AeroTypography.family
            font.pixelSize: AeroTypography.body
            font.weight: AeroTypography.weightMedium
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: AeroMotion.fast } }
        }
    }

    // ── Hover animation (100-140ms) ───────────────────────────────────────────
    Behavior on scale {
        NumberAnimation { duration: AeroMotion.fast; easing.type: AeroMotion.easingStandard }
    }

    scale: root.pressed ? 0.97 : 1.0

}
