// AeroPanel.qml
// Layered surface container with a subtle shadow-free elevation ladder and an
// optional 2px accent top strip. Elevation is expressed through border strength
// plus a dark under-band (offset 3px) so floating panels read as raised without
// blur/GPU cost.
//
// Properties:
//   elevation    (int)   — 0 base, 1 raised, 2 floating (overlay), 3 modal/accented
//   accentStrip  (bool)  — draw a 2px cyan accent strip along the top edge
//   radius       (real)  — corner radius (default AeroMetrics.radiusPanel)
//   contentMargin(real)  — inner margin around the default content

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property int elevation: 0
    property bool accentStrip: false
    property real radius: AeroMetrics.radiusPanel
    property real contentMargin: AeroMetrics.gap
    default property alias content: _content.data

    // ── Derived surface ────────────────────────────────────────────────────────
    readonly property color _fill:   root.elevation >= 2 ? AeroColors.surfaceRaised : AeroColors.surface
    readonly property color _stroke: root.elevation >= 2 ? AeroColors.borderStrong   : AeroColors.border

    // ── Under-band — shadow-free depth for elevated/overlay panels ─────────────
    Rectangle {
        visible: root.elevation >= 3
        anchors.fill: parent
        anchors.topMargin: AeroMetrics.elevBandOffset
        color: "#66000000"
        radius: root.radius
    }
    Rectangle {
        visible: root.elevation === 2
        anchors.fill: parent
        anchors.topMargin: Math.max(1, AeroMetrics.elevBandOffset - 1)
        color: "#40000000"
        radius: root.radius
    }

    // ── Panel face ─────────────────────────────────────────────────────────────
    Rectangle {
        id: _panel
        anchors.fill: parent
        color: root._fill
        border.color: root._stroke
        border.width: AeroMetrics.borderThin
        radius: root.radius
        clip: false

        Rectangle {
            visible: root.accentStrip
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 2
            radius: 1
            color: AeroColors.accent
        }

        Item {
            id: _content
            anchors.fill: parent
            anchors.margins: root.contentMargin
        }
    }
}