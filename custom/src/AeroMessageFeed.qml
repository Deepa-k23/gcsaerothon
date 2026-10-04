// AeroMessageFeed.qml
// AeroTHON-GCS V2 — Unified chronological vehicle message feed.
//
// Newest messages appear at the top. Severity is distinguished visually
// (dot color + background tint) without filter controls.
// A "Clear" button at the bottom edge removes all messages.
// Bounded history at 200 entries.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import AeroTHON 1.0
import "qrc:/Custom/AeroTHON/theme"
import "qrc:/Custom/AeroTHON/components"

Rectangle {
    id: root

    // ── Public API ──────────────────────────────────────────────────────────────
    property var vehicle

    property bool showBorder: false

    // ── Appearance ──────────────────────────────────────────────────────────────
    color: showBorder ? AeroColors.surface : "transparent"
    border.color: AeroColors.border
    border.width: showBorder ? 1 : 0
    radius: showBorder ? AeroMetrics.radiusPanel : 0

    // ── Unread counter ──────────────────────────────────────────────────────────
    property int _unreadCount: 0

    // ── Severity mapping ────────────────────────────────────────────────────────
    function mapSeverity(s) {
        var n = s || 0
        if (n <= 2) return "CRITICAL" // 0:EMERGENCY, 1:ALERT, 2:CRITICAL
        if (n <= 4) return "WARNING" // 3:ERROR, 4:WARNING
        if (n === 5) return "MISSION" // 5:NOTICE
        if (n === 6) return "INFO" // 6:INFO
        return "SYSTEM" // 7:DEBUG
    }

    // ── Header ──────────────────────────────────────────────────────────────────
    RowLayout {
        id: feedHeader
        anchors.top:        parent.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.topMargin:  6
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        height: 22
        spacing: 6

        Text {
            text:           "MESSAGES"
            color:          AeroColors.textMuted
            font.family:    AeroTypography.family
            font.pixelSize: AeroTypography.caption
            font.weight:    Font.Medium
            font.capitalization: Font.AllUppercase
        }

        // Unread badge
        Rectangle {
            visible: root._unreadCount > 0
            width:  Math.max(18, badgeText.implicitWidth + 8)
            height: 16
            radius: 8
            color:  AeroColors.accentSubtle

            Text {
                id: badgeText
                anchors.centerIn: parent
                text:           root._unreadCount.toString()
                color:          AeroColors.accent
                font.family:    AeroTypography.family
                font.pixelSize: AeroTypography.caption
                font.weight:    Font.DemiBold
            }
        }

        Item { Layout.fillWidth: true }

        // Clear old messages button
        Rectangle {
            implicitWidth: clearText.implicitWidth + 14
            implicitHeight: 20
            radius: AeroMetrics.radiusSmall
            color: clearMouseArea.containsMouse ? AeroColors.surfaceHover : AeroColors.surfaceRaised
            border.color: AeroColors.border
            border.width: 1

            Text {
                id: clearText
                anchors.centerIn: parent
                text: "Clear"
                color: AeroColors.textSecondary
                font.family: AeroTypography.family
                font.pixelSize: AeroTypography.micro
            }
            HoverHandler { id: clearMouseArea }
            TapHandler {
                onTapped: AeroMessageModel.clear()
            }
        }
    }

    // Separator under header
    Rectangle {
        anchors.top:   feedHeader.bottom
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 1
        color:  AeroColors.border
    }

    // ── Message ListView ────────────────────────────────────────────────────────
    // Newest at top (model prepends at index 0). Auto-scroll to top on new message.
    ListView {
        id: msgList
        anchors.top:    feedHeader.bottom
        anchors.topMargin: 1
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        clip:    true
        spacing: 1

        model: AeroMessageModel

        // Scroll to newest (top) on new message
        onCountChanged: {
            if (count > 0) {
                msgList.positionViewAtBeginning()
            }
        }

        delegate: Item {
            id: delegateItem
            width:  ListView.view.width
            height: msgRow.implicitHeight
            visible: true

            // Animate delegate appearance
            opacity: 0
            ListView.onAdd: SequentialAnimation {
                NumberAnimation {
                    target:   delegateItem
                    property: "opacity"
                    from:     0
                    to:       1
                    duration: AeroMotion.alert
                }
            }

            AeroMessageRow {
                id: msgRow
                width:     parent.width
                priority:  root.mapSeverity(model.severity)
                source:    "SYS " + model.sysId
                message:   model.text
                detail:    model.description
                alertId:   model.id
                acknowledged: true
                active: false
                timestamp: Qt.formatTime(new Date(model.timestamp), "HH:mm:ss")
            }
        }

        // Empty state
        Item {
            anchors.fill: parent
            visible: msgList.count === 0

            Text {
                anchors.centerIn: parent
                text:           "No messages"
                color:          AeroColors.textMuted
                font.family:    AeroTypography.family
                font.pixelSize: AeroTypography.caption
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }
    }

}
