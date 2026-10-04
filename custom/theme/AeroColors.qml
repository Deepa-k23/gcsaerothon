pragma Singleton
import QtQuick

QtObject {
    // ── Backgrounds (Matte Charcoal Titanium & Slate) ─────────────────────────
    readonly property color background:        "#0F0F12"  // application canvas
    readonly property color surface:           "#18181B"  // primary panels / docks
    readonly property color surfaceRaised:     "#222226"  // elevated panel / popup
    readonly property color surfaceHover:      "#27272A"  // interactive hover fill
    readonly property color surfaceCard:       "#1E1E22"  // dense cards / chips
    readonly property color surfacePressed:    "#141416"  // pressed feedback

    // ── Structural lines (Industrial Graphite) ────────────────────────────────
    readonly property color border:            "#2E2E33"
    readonly property color borderStrong:      "#3F3F46"

    // ── Accent (Precision Safety Orange) ──────────────────────────────────────
    readonly property color accent:            "#F97316"
    readonly property color accentDim:         "#C2410C"
    readonly property color accentSubtle:      "#2A160A"
    readonly property color textOnAccent:      "#0C0A09"  // text on solid accent fill

    // ── Text hierarchy (Crisp Titanium White & Aluminum) ───────────────────────
    readonly property color textPrimary:       "#F4F4F5"
    readonly property color textSecondary:     "#A1A1AA"
    readonly property color textMuted:         "#71717A"
    readonly property color textAccent:        accent

    // ── Safety semantics (NEVER follow the adaptive accent) ──────────────────
    readonly property color healthy:           "#22C55E"
    readonly property color advisory:          "#F59E0B"
    readonly property color critical:          "#EF4444"
    readonly property color criticalDim:       "#3B1212"

    // ── Overlay scrims ────────────────────────────────────────────────────────
    readonly property color scrim:             "#99000000"  // Qt.rgba(0,0,0,0.6)
    readonly property color scrimLight:        "#66000000"  // Qt.rgba(0,0,0,0.4)

    // ── HUD / attitude instrument (Industrial Aviation) ──────────────────────
    readonly property color hudSky:            "#1E293B"
    readonly property color hudGround:         "#382414"
    readonly property color hudHorizon:        accent
    readonly property color hudTape:           "#D918181B"  // translucent instrument tape

    // ── Mission / route ───────────────────────────────────────────────────────
    readonly property color missionRoute:      accent      // orange – active route
    readonly property color completedRoute:    "#38BDF8"   // sky blue – completed path
    readonly property color waypointActive:    accent
    readonly property color waypointDone:      healthy
    readonly property color vehicleIcon:       textPrimary

    // ── Graph node states ────────────────────────────────────────────────────
    readonly property color nodeNotStarted:    borderStrong
    readonly property color nodeActive:        accent
    readonly property color nodeCompleted:     healthy
    readonly property color nodeFailed:        critical
    readonly property color nodeSkipped:       advisory
    // Translucent fills for graph canvases (alpha-encoded)
    readonly property color nodeCompletedFill: "#8A22C55E" // healthy @ ~54%
    readonly property color nodeActiveFill:    accentSubtle

    // ── Detection markers ────────────────────────────────────────────────────
    readonly property color detectionQR:       "#A855F7"   // purple
    readonly property color detectionBanner:   healthy
    readonly property color detectionObstacle: advisory
    readonly property color detectionRedZone:  critical

    // ── Charts ────────────────────────────────────────────────────────────────
    readonly property color chartLine:         accent
    readonly property color chartArea:         "#26160C"   // orange-tinted chart fill
    readonly property color chartSecondary:    "#38BDF8"   // sky series
    readonly property color chartGrid:         "#27272A"

    // ── Legacy aliases ────────────────────────────────────────────────────────
    readonly property color active:            accent
    readonly property color activeSubtle:      accentSubtle
    readonly property color success:           healthy
    readonly property color warning:           advisory
    readonly property color glass:             surface
    readonly property color flightPath:        missionRoute
    readonly property color obstacle:          detectionObstacle
    readonly property color redZone:           detectionRedZone
}