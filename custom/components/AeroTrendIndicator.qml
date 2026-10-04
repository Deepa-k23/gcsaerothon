// AeroTrendIndicator.qml
// Tiny trend arrow: up / stable / down.
// Appears on trend change (80ms fade-in), auto-fades after 3 seconds.
//
// Properties:
//   trend (int) — 1 = up, 0 = stable, -1 = down

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property int trend: 0   // 1 = up, 0 = stable, -1 = down

    implicitWidth:  12
    implicitHeight: 12

    // ── Derived visuals ───────────────────────────────────────────────────────
    readonly property string _arrowChar: {
        if (root.trend > 0)  return "▲"
        if (root.trend < 0)  return "▼"
        return "●"           // stable: small dot
    }

    readonly property color _arrowColor: {
        if (root.trend > 0)  return AeroColors.healthy
        if (root.trend < 0)  return AeroColors.critical
        return AeroColors.textMuted
    }

    // ── Opacity — shown for 3s then fades ────────────────────────────────────
    opacity: 0.0

    // Trigger on trend change: show immediately then schedule auto-fade
    onTrendChanged: {
        fadeInAnim.stop()
        holdTimer.stop()
        fadeOutAnim.stop()
        root.opacity = 0.0
        fadeInAnim.start()
    }

    // Fade in (80ms)
    NumberAnimation {
        id: fadeInAnim
        target:   root
        property: "opacity"
        to:       1.0
        duration: AeroMotion.micro    // 80ms
        easing.type: AeroMotion.easingEnter
        onStopped: holdTimer.start()
    }

    // Hold 3 seconds
    Timer {
        id: holdTimer
        interval: 3000
        repeat:   false
        onTriggered: fadeOutAnim.start()
    }

    // Fade out (120ms)
    NumberAnimation {
        id: fadeOutAnim
        target:   root
        property: "opacity"
        to:       0.0
        duration: AeroMotion.fast     // 120ms
        easing.type: AeroMotion.easingExit
    }

    // ── Arrow text ────────────────────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        text:  root._arrowChar
        color: root._arrowColor
        font.family:    AeroTypography.family
        font.pixelSize: AeroTypography.micro
        font.weight:    AeroTypography.weightBold

        Behavior on color { ColorAnimation { duration: AeroMotion.micro } }
    }
}
