pragma Singleton
import QtQuick

QtObject {
    // ── Corner radii ─────────────────────────────────────────────────────────
    readonly property int radiusSmall:    3
    readonly property int radiusControl:  4
    readonly property int radiusPanel:    6
    readonly property int radiusCard:     7
    readonly property int clipCorner:     8   // diagonal angular clip

    // ── Spacing ──────────────────────────────────────────────────────────────
    readonly property int gap:            8
    readonly property int gapSmall:       4
    readonly property int gapMicro:       2
    readonly property int gapLarge:       12
    readonly property int gapXL:          16

    // ── Shell geometry ───────────────────────────────────────────────────────
    readonly property int topBarHeight:        56
    readonly property int navRailWidth:        64   // collapsed — content inset source
    readonly property int navRailWidthExpanded: 208 // hover-expand target (overlay, no content push)
    readonly property int telemetryRailHeight: 72
    readonly property int missionGraphNormal:  112
    readonly property int missionGraphCollapsed: 52
    readonly property int missionGraphExpanded: 220

    // ── Elevation (shadow-free: offset band + border strength) ───────────────
    readonly property int elevBandOffset:     3    // px the dark under-band is offset
    readonly property int elevBandRadius:     6

    // ── Column sizing ─────────────────────────────────────────────────────────
    readonly property real leftColumnRatio:  0.215
    readonly property real rightColumnRatio: 0.215
    readonly property int leftColumnMin:     290
    readonly property int leftColumnMax:     360
    readonly property int rightColumnMin:    260
    readonly property int rightColumnMax:    340

    // ── Component sizes ───────────────────────────────────────────────────────
    readonly property int statusRowHeight:   24
    readonly property int quickActionHeight: 44
    readonly property int quickActionWidth:  78
    readonly property int touchTarget:       44
    readonly property int nodeSize:          18   // mission graph node circle
    readonly property int nodeTooltipWidth:  200

    // ── Border widths ─────────────────────────────────────────────────────────
    readonly property real borderThin:       1.0
    readonly property real borderAccent:     1.5
}
