// AeroTechnicalFrame.qml
// A Rectangle with one angular clipped corner and a thin cyan border.
// Uses a Canvas overlay to render the corner notch polygon.
//
// Properties:
//   clipSize    (int,    8)           — size of the diagonal clip in px
//   borderColor (color, AeroColors.accent)
//   borderWidth (real,  1)
//   clipCorner  (string,"topRight")   — "topRight"|"topLeft"|"bottomRight"|"bottomLeft"
//   fillColor   (color, AeroColors.surface)

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    // ── Public API ────────────────────────────────────────────────────────────
    property int    clipSize:    AeroMetrics.clipCorner
    property color  borderColor: AeroColors.accent
    property real   borderWidth: AeroMetrics.borderThin
    property string clipCorner:  "topRight"
    property color  fillColor:   AeroColors.surface

    // Allow children to be placed inside the content area
    default property alias contentData: contentLoader.data

    // ── Internals ─────────────────────────────────────────────────────────────

    // Helper computed properties for clip polygon vertices
    readonly property real _w: width
    readonly property real _h: height
    readonly property real _c: clipSize

    // Background fill painted via Canvas to match the clip shape
    Canvas {
        id: fillCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath()
            _buildPath(ctx, root._w, root._h, root._c, root.clipCorner)
            ctx.fillStyle = root.fillColor
            ctx.fill()
        }

        // Repaint whenever geometry or fill changes
        Connections {
            target: root
            function onWidthChanged()      { fillCanvas.requestPaint() }
            function onHeightChanged()     { fillCanvas.requestPaint() }
            function onFillColorChanged()  { fillCanvas.requestPaint() }
            function onClipSizeChanged()   { fillCanvas.requestPaint() }
            function onClipCornerChanged() { fillCanvas.requestPaint() }
        }
    }

    // Content sits on top of the fill layer
    Item {
        id: contentLoader
        anchors.fill: parent
    }

    // Border overlay drawn on top of everything
    Canvas {
        id: borderCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.beginPath()

            // Inset the stroke by half border width so it doesn't bleed outside
            var inset = root.borderWidth / 2
            _buildPath(ctx,
                       root._w - inset,
                       root._h - inset,
                       root._c,
                       root.clipCorner,
                       inset, inset)

            ctx.strokeStyle = root.borderColor
            ctx.lineWidth   = root.borderWidth
            ctx.stroke()
        }

        Connections {
            target: root
            function onWidthChanged()       { borderCanvas.requestPaint() }
            function onHeightChanged()      { borderCanvas.requestPaint() }
            function onBorderColorChanged() { borderCanvas.requestPaint() }
            function onBorderWidthChanged() { borderCanvas.requestPaint() }
            function onClipSizeChanged()    { borderCanvas.requestPaint() }
            function onClipCornerChanged()  { borderCanvas.requestPaint() }
        }
    }

    // ── Path builder (shared between fill and border canvases) ────────────────
    // Draws a rectangle with one corner replaced by a diagonal cut.
    // ox, oy: origin offset (used for border inset).
    function _buildPath(ctx, w, h, c, corner, ox, oy) {
        var x = (ox !== undefined) ? ox : 0
        var y = (oy !== undefined) ? oy : 0

        switch (corner) {
        case "topLeft":
            ctx.moveTo(x + c, y)
            ctx.lineTo(x + w, y)
            ctx.lineTo(x + w, y + h)
            ctx.lineTo(x,     y + h)
            ctx.lineTo(x,     y + c)
            ctx.closePath()
            break
        case "topRight":
            ctx.moveTo(x,         y)
            ctx.lineTo(x + w - c, y)
            ctx.lineTo(x + w,     y + c)
            ctx.lineTo(x + w,     y + h)
            ctx.lineTo(x,         y + h)
            ctx.closePath()
            break
        case "bottomRight":
            ctx.moveTo(x,         y)
            ctx.lineTo(x + w,     y)
            ctx.lineTo(x + w,     y + h - c)
            ctx.lineTo(x + w - c, y + h)
            ctx.lineTo(x,         y + h)
            ctx.closePath()
            break
        case "bottomLeft":
            ctx.moveTo(x,     y)
            ctx.lineTo(x + w, y)
            ctx.lineTo(x + w, y + h)
            ctx.lineTo(x + c, y + h)
            ctx.lineTo(x,     y + h - c)
            ctx.closePath()
            break
        default: // fallback: normal rectangle
            ctx.rect(x, y, w, h)
            break
        }
    }
}
