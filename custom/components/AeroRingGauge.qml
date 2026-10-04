// AeroRingGauge.qml
// Circular progress ring using Shape + PathArc.
// Value changes animate over 200ms.
//
// Properties:
//   value       (real)  — 0.0 – 100.0
//   size        (int)   — outer diameter, default 48
//   trackColor  (color) — ring background track
//   fillColor   (color) — ring foreground fill
//   labelText   (string)— centre top label (e.g. "82")
//   unitText    (string)— centre bottom unit (e.g. "%")
//   strokeWidth (real)  — 3

import QtQuick
import QtQuick.Shapes
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property real   value:       0.0
    property int    size:        48
    property color  trackColor:  AeroColors.border
    property color  fillColor:   AeroColors.accent
    property string labelText:   ""
    property string unitText:    ""
    property real   strokeWidth: 3.0

    implicitWidth:  root.size
    implicitHeight: root.size

    // ── Animated arc angle ────────────────────────────────────────────────────
    property real _animatedValue: root.value

    Behavior on _animatedValue {
        NumberAnimation {
            duration:   AeroMotion.telemetry   // 220ms
            easing.type: AeroMotion.easingStandard
        }
    }

    onValueChanged: _animatedValue = root.value

    // Derived arc parameters
    readonly property real _cx:        root.size / 2
    readonly property real _cy:        root.size / 2
    readonly property real _r:         (root.size / 2) - root.strokeWidth / 2 - 1
    readonly property real _startAngle: -90                          // 12 o'clock
    readonly property real _sweepDeg:   3.5999 * root._animatedValue // 0→360

    // Helper: angle in degrees → x,y on circle
    function _px(angleDeg) { return _cx + _r * Math.cos(angleDeg * Math.PI / 180) }
    function _py(angleDeg) { return _cy + _r * Math.sin(angleDeg * Math.PI / 180) }

    // ── Shape ─────────────────────────────────────────────────────────────────
    Shape {
        id: gaugeShape
        anchors.fill: parent
        antialiasing: true
        smooth: true

        // Track (full circle)
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.strokeWidth
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            PathAngleArc {
                centerX:      root._cx
                centerY:      root._cy
                radiusX:      root._r
                radiusY:      root._r
                startAngle:   -90
                sweepAngle:   360
            }
        }

        // Fill arc
        ShapePath {
            id: fillPath
            strokeColor: root.fillColor
            strokeWidth: root.strokeWidth
            fillColor:   "transparent"
            capStyle:    ShapePath.RoundCap

            PathAngleArc {
                centerX:    root._cx
                centerY:    root._cy
                radiusX:    root._r
                radiusY:    root._r
                startAngle: -90
                sweepAngle: Math.min(root._sweepDeg, 359.99)  // avoid degenerate full arc
            }
        }
    }

    // ── Centre labels ─────────────────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        spacing: -1

        Text {
            id: mainLabel
            visible: root.labelText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text:  root.labelText
            color: AeroColors.textPrimary
            font.family:    AeroTypography.dataFamily
            font.pixelSize: root.size <= 48 ? AeroTypography.caption : AeroTypography.body
            font.weight:    AeroTypography.weightBold
        }

        Text {
            id: unitLabel
            visible: root.unitText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            text:  root.unitText
            color: AeroColors.textMuted
            font.family:    AeroTypography.dataFamily
            font.pixelSize: AeroTypography.micro
        }
    }
}
