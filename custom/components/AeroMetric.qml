// AeroMetric.qml
// Label / value / unit readout for telemetry-style rows. The value is rendered
// in the bundled mono data face for precise, locked digits.
//
// Properties:
//   label      (string) — muted UPPERCASE caption at the left
//   value      (string) — technical value (mono, DemiBold)
//   unit       (string) — muted unit suffix
//   valueColor (color)  — value text color (default textPrimary)

import QtQuick
import QtQuick.Layouts
import "qrc:/Custom/AeroTHON/theme"

RowLayout {
    id: root

    property string label: ""
    property string value: "–"
    property string unit: ""
    property color valueColor: AeroColors.textPrimary

    spacing: AeroMetrics.gapSmall

    Text {
        text: root.label.toUpperCase()
        color: AeroColors.textMuted
        font.family: AeroTypography.family
        font.pixelSize: AeroTypography.caption
        font.letterSpacing: AeroTypography.labelSpacing
        Layout.fillWidth: true
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignLeft
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        text: root.value
        color: root.valueColor
        font.family: AeroTypography.dataFamily
        font.pixelSize: AeroTypography.value
        font.weight: AeroTypography.weightDemiBold
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        Behavior on color { ColorAnimation { duration: AeroMotion.color } }
    }

    Text {
        visible: root.unit !== ""
        text: root.unit
        color: AeroColors.textMuted
        font.family: AeroTypography.family
        font.pixelSize: AeroTypography.caption
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
}