// AeroNodeTooltip.qml
// AeroTHON-GCS V2 — Hover tooltip for mission graph nodes.
//
// Shows TASK, STATUS, STARTED, COMPLETED, STAGE TIME, EXECUTION, and live
// ELAPSED counter when the node is active.
// Fades in (opacity 0→1) via a Behavior on visible.

import QtQuick
import QtQuick.Layouts
import "qrc:/Custom/AeroTHON/theme"

Rectangle {
    id: root

    // ── Public API ──────────────────────────────────────────────────────────────
    property string nodeLabel:           ""
    property string nodeState:           ""
    property string startedAt:           ""
    property string completedAt:         ""
    property real   stageDurationMs:     0
    property real   executionDurationMs: 0
    property bool   isActive:           false

    // ── Geometry ────────────────────────────────────────────────────────────────
    width:  200
    implicitHeight: contentCol.implicitHeight + 20   // 10px top + 10px bottom margin

    // ── Appearance ──────────────────────────────────────────────────────────────
    color:        AeroColors.surfaceRaised
    border.color: AeroColors.borderStrong
    border.width: 1
    radius:       AeroMetrics.radiusPanel

    // ── Fade in/out ─────────────────────────────────────────────────────────────
    opacity: visible ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: AeroMotion.fast }
    }

    // ── State colour helper ──────────────────────────────────────────────────────
    function _stateColor(st) {
        if (st === "active")    return AeroColors.accent
        if (st === "completed") return AeroColors.healthy
        if (st === "failed")    return AeroColors.critical
        return AeroColors.textMuted
    }

    // ── Live elapsed timer (active nodes only) ───────────────────────────────────
    property string _elapsedText: "0 s"

    Timer {
        id: elapsedTimer
        interval: 1000
        running:  root.visible && root.isActive
        repeat:   true
        onTriggered: {
            // Rough elapsed from startedAt if parseable, else count up from display
            var startMs = root.startedAt ? Date.parse(root.startedAt) : 0
            if (!isNaN(startMs) && startMs > 0) {
                var sec = Math.floor((Date.now() - startMs) / 1000)
                root._elapsedText = sec + " s"
            } else {
                var cur = parseInt(root._elapsedText) || 0
                root._elapsedText = (cur + 1) + " s"
            }
        }
    }

    // ── Content ─────────────────────────────────────────────────────────────────
    Column {
        id: contentCol
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.topMargin:   10
        anchors.leftMargin:  10
        anchors.rightMargin: 10
        spacing: 4

        // Row builder component (inline)
        component InfoRow: RowLayout {
            property string rowLabel: ""
            property string rowValue: ""
            property color  rowColor: AeroColors.textPrimary

            Layout.fillWidth: true
            spacing: 4

            Text {
                text:           infoRow.rowLabel
                color:          AeroColors.textMuted
                font.family:    AeroTypography.family
                font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text:           infoRow.rowValue
                color:          infoRow.rowColor
                font.family:    AeroTypography.dataFamily
                font.pixelSize: AeroTypography.caption
                elide:          Text.ElideRight
                Layout.maximumWidth: 110
            }
        }

        // TASK
        RowLayout {
            width: parent.width
            spacing: 4
            Text {
                text: "TASK"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.nodeLabel; color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
                elide: Text.ElideRight; Layout.maximumWidth: 110
            }
        }

        // STATUS
        RowLayout {
            width: parent.width
            spacing: 4
            Text {
                text: "STATUS"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text:  root.nodeState.toUpperCase()
                color: root._stateColor(root.nodeState)
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
                font.weight: Font.DemiBold
            }
        }

        // STARTED (conditional)
        RowLayout {
            visible: root.startedAt !== ""
            width: parent.width
            spacing: 4
            Text {
                text: "STARTED"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.startedAt; color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
            }
        }

        // COMPLETED (conditional)
        RowLayout {
            visible: root.completedAt !== ""
            width: parent.width
            spacing: 4
            Text {
                text: "COMPLETED"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.completedAt; color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
            }
        }

        // STAGE TIME (conditional)
        RowLayout {
            visible: root.stageDurationMs > 0
            width: parent.width
            spacing: 4
            Text {
                text: "STAGE TIME"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (root.stageDurationMs / 1000).toFixed(0) + " s"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
            }
        }

        // EXECUTION (conditional)
        RowLayout {
            visible: root.executionDurationMs > 0
            width: parent.width
            spacing: 4
            Text {
                text: "EXECUTION"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (root.executionDurationMs / 1000).toFixed(0) + " s"
                color: AeroColors.textPrimary
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
            }
        }

        // ELAPSED — live counter for active nodes
        RowLayout {
            visible: root.isActive
            width: parent.width
            spacing: 4
            Text {
                text: "ELAPSED"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text:  root._elapsedText
                color: AeroColors.accent
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
                font.weight: Font.DemiBold
            }
        }

        // NOT STARTED fallback
        RowLayout {
            visible: root.startedAt === "" && !root.isActive
            width: parent.width
            spacing: 4
            Text {
                text: "STATUS"; color: AeroColors.textMuted
                font.family: AeroTypography.family; font.pixelSize: AeroTypography.caption
                font.capitalization: Font.AllUppercase
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "NOT COMPLETED"; color: AeroColors.textMuted
                font.family: AeroTypography.dataFamily; font.pixelSize: AeroTypography.caption
            }
        }
    }
}
