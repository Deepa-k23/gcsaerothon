// AeroDataCard.qml
// Premium data card — deep navy surface, radius 7, subtle border.
// Thin top border accent in cyan. Internal padding 10px.
//
// Properties:
//   title   (string) — optional card header text
//   content — default property, children placed in the content area

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property string title: ""
    default property alias content: contentArea.data

    // ── Geometry ──────────────────────────────────────────────────────────────
    implicitWidth:  200
    implicitHeight: column.implicitHeight + AeroMetrics.gap * 2

    // ── Card background ───────────────────────────────────────────────────────
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius:       AeroMetrics.radiusCard       // 7px
        color:        AeroColors.surfaceCard
        border.color: AeroColors.border
        border.width: AeroMetrics.borderThin

        // Cyan top accent bar
        Rectangle {
            id: topAccent
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            height:        AeroMetrics.borderThin * 1.5   // ~1.5px
            radius:        AeroMetrics.radiusCard
            color:         AeroColors.accent
            // Only round top corners — cover bottom rounding with a fill below
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                height:         parent.radius
                color:          parent.color
            }
        }
    }

    // ── Content column ────────────────────────────────────────────────────────
    Column {
        id: column
        anchors {
            top:    parent.top
            left:   parent.left
            right:  parent.right
            topMargin:    AeroMetrics.gap + 2   // clear the accent bar + padding
            bottomMargin: AeroMetrics.gap
            leftMargin:   AeroMetrics.gap + 2
            rightMargin:  AeroMetrics.gap + 2
        }
        spacing: AeroMetrics.gapSmall

        // Optional title
        Text {
            id: titleLabel
            visible: root.title !== ""
            width:   parent.width
            text:    root.title
            color:   AeroColors.textSecondary
            font.family:    AeroTypography.family
            font.pixelSize: AeroTypography.caption   // 16px
            font.weight:    AeroTypography.weightMedium
            elide:          Text.ElideRight
        }

        // Divider below title
        Rectangle {
            visible: root.title !== ""
            width:   parent.width
            height:  1
            color:   AeroColors.border
        }

        // Content slot
        Item {
            id: contentArea
            width:          parent.width
            implicitHeight: childrenRect.height
        }
    }
}
