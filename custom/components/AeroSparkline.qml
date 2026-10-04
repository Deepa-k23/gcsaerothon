// AeroSparkline.qml
// Mini rolling line chart drawn on a Canvas.
// Redraws whenever the model array changes.
//
// Properties:
//   model     (var)   — array of numbers (most-recent-last)
//   lineColor (color) — AeroColors.chartLine
//   fillColor (color) — AeroColors.chartArea
//   showDot   (bool)  — dot at latest data point
//   lineWidth (real)  — 1.5

import QtQuick
import "qrc:/Custom/AeroTHON/theme"

Item {
    id: root

    property var   model:     []
    property color lineColor: AeroColors.chartLine
    property color fillColor: AeroColors.chartArea
    property bool  showDot:   true
    property real  lineWidth: 1.5

    implicitWidth:  120
    implicitHeight: 36

    // ── Internal animated scroll offset ──────────────────────────────────────
    // When data updates we briefly animate a translation to mimic left-scroll.
    property real _scrollOffset: 0.0

    onModelChanged: {
        scrollAnim.restart()
        sparkCanvas.requestPaint()
    }

    SequentialAnimation {
        id: scrollAnim
        // Snap to right (new data came in from the right)
        PropertyAction  { target: root; property: "_scrollOffset"; value: 6 }
        NumberAnimation {
            target:   root
            property: "_scrollOffset"
            to:       0
            duration: AeroMotion.chart          // ~280ms
            easing.type: AeroMotion.easingStandard
        }
    }

    on_ScrollOffsetChanged: sparkCanvas.requestPaint()

    // ── Canvas ────────────────────────────────────────────────────────────────
    Canvas {
        id: sparkCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var data = root.model
            if (!data || data.length < 2) return

            // Translate by the scroll offset
            ctx.save()
            ctx.translate(-root._scrollOffset, 0)

            // Find min/max for normalisation
            var minVal = data[0]
            var maxVal = data[0]
            for (var i = 1; i < data.length; i++) {
                if (data[i] < minVal) minVal = data[i]
                if (data[i] > maxVal) maxVal = data[i]
            }
            var range = maxVal - minVal
            if (range < 0.001) range = 1.0

            var padT = 2
            var padB = 2
            var plotH = height - padT - padB
            var stepX  = (width + root._scrollOffset) / (data.length - 1)

            function xAt(idx) { return idx * stepX }
            function yAt(v)   { return padT + plotH * (1.0 - (v - minVal) / range) }

            // ── Fill area ────────────────────────────────────────────────────
            ctx.beginPath()
            ctx.moveTo(xAt(0), height)
            ctx.lineTo(xAt(0), yAt(data[0]))
            for (var j = 1; j < data.length; j++) {
                ctx.lineTo(xAt(j), yAt(data[j]))
            }
            ctx.lineTo(xAt(data.length - 1), height)
            ctx.closePath()
            ctx.fillStyle = root.fillColor
            ctx.fill()

            // ── Line ─────────────────────────────────────────────────────────
            ctx.beginPath()
            ctx.moveTo(xAt(0), yAt(data[0]))
            for (var k = 1; k < data.length; k++) {
                ctx.lineTo(xAt(k), yAt(data[k]))
            }
            ctx.strokeStyle = root.lineColor
            ctx.lineWidth   = root.lineWidth
            ctx.lineJoin    = "round"
            ctx.lineCap     = "round"
            ctx.stroke()

            // ── Latest-point dot ─────────────────────────────────────────────
            if (root.showDot && data.length > 0) {
                var lastX = xAt(data.length - 1)
                var lastY = yAt(data[data.length - 1])
                ctx.beginPath()
                ctx.arc(lastX, lastY, 2.5, 0, Math.PI * 2)
                ctx.fillStyle = root.lineColor
                ctx.fill()
            }

            ctx.restore()
        }

        Connections {
            target: root
            function onLineColorChanged() { sparkCanvas.requestPaint() }
            function onFillColorChanged() { sparkCanvas.requestPaint() }
            function onShowDotChanged()   { sparkCanvas.requestPaint() }
            function onLineWidthChanged() { sparkCanvas.requestPaint() }
            function onWidthChanged()     { sparkCanvas.requestPaint() }
            function onHeightChanged()    { sparkCanvas.requestPaint() }
        }
    }
}
