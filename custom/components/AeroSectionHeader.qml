// AeroSectionHeader.qml
// Uppercase technical section label with an optional trailing rule line.
//
// Properties:
//   text     (string) — label, rendered UPPERCASE with spacing
//   color    (color)  — text color (default textSecondary)
//   showRule (bool)   — draw a 1px rule filling the remaining width

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property string text: ""
    property color color: AeroColors.textSecondary
    property bool showRule: true

    implicitHeight: 20

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.text.toUpperCase()
        color: root.color
        font.family: AeroTypography.family
        font.pixelSize: AeroTypography.caption
        font.weight: AeroTypography.weightDemiBold
        font.letterSpacing: AeroTypography.sectionSpacing
    }

    Rectangle {
        visible: root.showRule
        anchors.left: labelText.right
        anchors.right: parent.right
        anchors.leftMargin: AeroMetrics.gap
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: AeroColors.border
    }
}