// AeroDivider.qml
// Horizontal or vertical 1px divider line.
//
// Properties:
//   orientation (string) — "horizontal"|"vertical"
//   length      (int)    — explicit length; if 0 the parent determines it

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property string orientation: "horizontal"
    property int    length:      0

    // ── Sizing ────────────────────────────────────────────────────────────────
    implicitWidth: {
        if (root.orientation === "vertical")   return 1
        return root.length > 0 ? root.length : 100
    }
    implicitHeight: {
        if (root.orientation === "horizontal") return 1
        return root.length > 0 ? root.length : 100
    }

    // ── Line ──────────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: AeroColors.border
        // 1px in the thin axis is enforced by the Item's implicitWidth/Height above
    }
}
