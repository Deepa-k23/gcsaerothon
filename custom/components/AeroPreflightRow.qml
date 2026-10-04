// AeroPreflightRow.qml
// Single row in the preflight check panel.
// Height 28px normal; expands to show detail on hover or click.
//
// Properties:
//   checkLabel (string) — check name
//   checkState (string) — "WAITING"|"CHECKING"|"PASS"|"ADVISORY"|"FAIL"|"INCOMPLETE"
//   detail     (string) — shown on hover/expand

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property string checkLabel: ""
    property string checkState: "WAITING"
    property string detail:     ""

    readonly property int _rowH: 28
    readonly property bool _expanded: hoverArea.containsMouse || _clicked
    property bool _clicked: false

    implicitWidth:  280
    implicitHeight: _expanded && detail !== "" ? _rowH + detailItem.implicitHeight + AeroMetrics.gapSmall : _rowH

    Behavior on implicitHeight {
        NumberAnimation { duration: AeroMotion.fast; easing.type: AeroMotion.easingStandard }
    }

    // ── State icon color resolver ─────────────────────────────────────────────
    readonly property color _iconColor: {
        switch (root.checkState) {
        case "PASS":       return AeroColors.healthy
        case "ADVISORY":   return AeroColors.advisory
        case "FAIL":       return AeroColors.critical
        case "CHECKING":   return AeroColors.accent
        case "INCOMPLETE": return AeroColors.textMuted
        default:           return AeroColors.borderStrong   // WAITING
        }
    }

    // ── Row background ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: hoverArea.containsMouse ? AeroColors.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: AeroMotion.micro } }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root._clicked = !root._clicked
    }

    // ── Main row content ──────────────────────────────────────────────────────
    Row {
        id: mainRow
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.leftMargin:  AeroMetrics.gapSmall
        anchors.rightMargin: AeroMetrics.gapSmall
        height: root._rowH
        spacing: AeroMetrics.gapSmall

        // State circle icon
        Item {
            width:  14
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            // Outer circle
            Rectangle {
                id: stateCircle
                anchors.fill: parent
                radius: width / 2
                color:  "transparent"
                border.color: root._iconColor
                border.width: 1.5

                Behavior on border.color { ColorAnimation { duration: AeroMotion.color } }

                // Inner fill for PASS / FAIL / ADVISORY
                Rectangle {
                    anchors.centerIn: parent
                    width:  6
                    height: 6
                    radius: width / 2
                    color:  root._iconColor
                    visible: root.checkState === "PASS" ||
                             root.checkState === "FAIL" ||
                             root.checkState === "ADVISORY"

                    Behavior on color { ColorAnimation { duration: AeroMotion.color } }
                }
            }

            // Pulsing overlay for CHECKING
            SequentialAnimation {
                running:   root.checkState === "CHECKING"
                loops:     Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation {
                    target:   stateCircle
                    property: "opacity"
                    from: 1.0; to: 0.3
                    duration: AeroMotion.panel
                    easing.type: AeroMotion.easingExit
                }
                NumberAnimation {
                    target:   stateCircle
                    property: "opacity"
                    from: 0.3; to: 1.0
                    duration: AeroMotion.panel
                    easing.type: AeroMotion.easingEnter
                }
            }
        }

        // Check label
        Text {
            text:  root.checkLabel
            color: {
                if (root.checkState === "FAIL")     return AeroColors.critical
                if (root.checkState === "ADVISORY") return AeroColors.advisory
                if (root.checkState === "PASS")     return AeroColors.textPrimary
                return AeroColors.textSecondary
            }
            font.family:    AeroTypography.family
            font.pixelSize: AeroTypography.caption   // 16px
            elide:          Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: AeroMotion.color } }
        }

        // Spacer
        Item { Layout.fillWidth: true }

        // State badge text
        Text {
            text: {
                switch (root.checkState) {
                case "PASS":       return "PASS"
                case "FAIL":       return "FAIL"
                case "ADVISORY":   return "WARN"
                case "CHECKING":   return "…"
                case "INCOMPLETE": return "—"
                default:           return ""
                }
            }
            color: root._iconColor
            font.family:    AeroTypography.dataFamily
            font.pixelSize: AeroTypography.micro
            font.weight:    AeroTypography.weightMedium
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: AeroMotion.color } }
        }
    }

    // ── Detail expansion ──────────────────────────────────────────────────────
    Item {
        id: detailItem
        visible: root._expanded && root.detail !== ""
        anchors.top:    mainRow.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.leftMargin:  AeroMetrics.gap + 14
        anchors.rightMargin: AeroMetrics.gapSmall
        implicitHeight: visible ? detailLabel.implicitHeight + AeroMetrics.gapSmall : 0

        Text {
            id: detailLabel
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            anchors.topMargin: AeroMetrics.gapSmall / 2
            text:     root.detail
            color:    AeroColors.textMuted
            font.family:    AeroTypography.family
            font.pixelSize: AeroTypography.caption
            wrapMode: Text.WordWrap
        }
    }

    // ── Bottom separator ──────────────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:  1
        color:   AeroColors.border
        opacity: 0.4
    }
}
