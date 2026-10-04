// AeroMessageRow.qml
// Single row in the live message feed.
// Normal height ~26px; expands to show detail on click.
// CRITICAL rows have a subtle red background tint.
//
// Properties:
//   priority  (string) — "CRITICAL"|"WARNING"|"MISSION"|"SYSTEM"|"INFO"
//   source    (string) — message source label
//   message   (string) — message body
//   timestamp (string) — time string
//   detail    (string) — expanded detail text (optional)

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property string priority:  "INFO"
    property string source:    ""
    property string message:   ""
    property string timestamp: ""
    property string detail:    ""
    property string alertId:   ""
    property bool acknowledged: false
    property bool active: true
    signal acknowledgeRequested(string alertId)

    implicitWidth:  400
    implicitHeight: expanded ? expandedHeight : collapsedHeight

    readonly property int collapsedHeight: 26
    readonly property int expandedHeight:  collapsedHeight + (detail !== "" ? detailText.implicitHeight + AeroMetrics.gapSmall * 2 + 4 : 0)
    property bool expanded: false

    Behavior on implicitHeight {
        NumberAnimation { duration: AeroMotion.fast; easing.type: AeroMotion.easingStandard }
    }

    // ── Priority color resolver ───────────────────────────────────────────────
    readonly property color _priorityColor: {
        switch (root.priority) {
        case "CRITICAL": return AeroColors.critical
        case "WARNING":  return AeroColors.advisory
        case "MISSION":  return AeroColors.accent
        case "SYSTEM":   return AeroColors.textSecondary
        default:         return AeroColors.textMuted    // INFO
        }
    }

    // ── Row background ────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: root.priority === "CRITICAL" ? AeroColors.criticalDim : "transparent"
        opacity: 0.6

        Behavior on color { ColorAnimation { duration: AeroMotion.color } }
    }

    // Hover tint
    Rectangle {
        anchors.fill: parent
        color:   AeroColors.surfaceHover
        opacity: hoverMouse.containsMouse ? 0.5 : 0.0
        Behavior on opacity { NumberAnimation { duration: AeroMotion.micro } }
    }

    MouseArea {
        id: hoverMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (root.detail !== "") root.expanded = !root.expanded
        }
    }

    // ── Collapsed row ─────────────────────────────────────────────────────────
    Row {
        id: mainRow
        anchors.top:     parent.top
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.leftMargin:  AeroMetrics.gapSmall
        anchors.rightMargin: AeroMetrics.gapSmall
        height: root.collapsedHeight
        spacing: AeroMetrics.gapSmall

        // Priority dot
        Rectangle {
            id: priorityDot
            width:  6
            height: 6
            radius: 3
            color:  root._priorityColor
            anchors.verticalCenter: parent.verticalCenter
        }

        // Timestamp
        Text {
            id: timestampText
            text:  root.timestamp
            color: AeroColors.textMuted
            font.family:    AeroTypography.dataFamily
            font.pixelSize: AeroTypography.caption   // 16px
            anchors.verticalCenter: parent.verticalCenter
            width: 52
        }

        // Source tag
        Text {
            id: sourceTag
            visible: root.source !== ""
            text:    "[" + root.source + "]"
            color:   root._priorityColor
            font.family:    AeroTypography.dataFamily
            font.pixelSize: AeroTypography.caption
            font.weight:    AeroTypography.weightMedium
            anchors.verticalCenter: parent.verticalCenter
        }

        // Message
        Text {
            text:  root.message
            color: root.priority === "CRITICAL" ? AeroColors.textPrimary : AeroColors.textSecondary
            font.family:    AeroTypography.family
            font.pixelSize: AeroTypography.caption
            elide:          Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(20, mainRow.width
                            - priorityDot.width
                            - timestampText.width
                            - (sourceTag.visible ? sourceTag.implicitWidth : 0)
                            - (ackText.visible ? ackText.implicitWidth : 0)
                            - (detailChevron.visible ? detailChevron.implicitWidth : 0)
                            - AeroMetrics.gapSmall * 5)
        }

        // Expand chevron
        Text {
            id: ackText
            visible: !root.acknowledged && root.alertId !== "" && (root.priority === "WARNING" || root.priority === "CRITICAL")
            text: "ACK"
            color: root._priorityColor
            font.family: AeroTypography.dataFamily
            font.pixelSize: AeroTypography.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            TapHandler { onTapped: root.acknowledgeRequested(root.alertId) }
        }

        Text {
            id: detailChevron
            visible: root.detail !== ""
            text:    root.expanded ? "▴" : "▾"
            color:   AeroColors.textMuted
            font.pixelSize: AeroTypography.micro
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // ── Expanded detail ───────────────────────────────────────────────────────
    Item {
        id: expandArea
        visible: root.expanded && root.detail !== ""
        anchors.top:     mainRow.bottom
        anchors.left:    parent.left
        anchors.right:   parent.right
        anchors.leftMargin:  AeroMetrics.gap + 6
        anchors.rightMargin: AeroMetrics.gapSmall
        height: visible ? detailText.implicitHeight + AeroMetrics.gapSmall * 2 : 0

        Rectangle {
            anchors.fill: parent
            color: AeroColors.surfaceRaised
            opacity: 0.6
            radius: AeroMetrics.radiusSmall
        }

        Text {
            id: detailText
            anchors {
                top:   parent.top
                left:  parent.left
                right: parent.right
                topMargin:    AeroMetrics.gapSmall
                leftMargin:   AeroMetrics.gapSmall
                rightMargin:  AeroMetrics.gapSmall
            }
            text:  root.detail
            color: AeroColors.textSecondary
            font.family:    AeroTypography.family
            font.pixelSize: AeroTypography.caption
            wrapMode:       Text.WordWrap
        }
    }

    // ── Bottom separator ──────────────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 1
        color:  AeroColors.border
        opacity: 0.5
    }
}
