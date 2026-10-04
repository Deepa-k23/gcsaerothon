#include "QGCPalette.h"
#include "QGCCorePlugin.h"

#include <QtCore/QDebug>

QList<QGCPalette*>   QGCPalette::_paletteObjects;

QGCPalette::Theme QGCPalette::_theme = QGCPalette::Dark;

QMap<int, QMap<int, QMap<QString, QColor>>> QGCPalette::_colorInfoMap;

QStringList QGCPalette::_colors;

QGCPalette::QGCPalette(QObject* parent) :
    QObject(parent),
    _colorGroupEnabled(true)
{
    if (_colorInfoMap.isEmpty()) {
        _buildMap();
    }

    // We have to keep track of all QGCPalette objects in the system so we can signal theme change to all of them
    _paletteObjects += this;
}

QGCPalette::~QGCPalette()
{
    bool fSuccess = _paletteObjects.removeOne(this);
    if (!fSuccess) {
        qWarning() << "Internal error";
    }
}

void QGCPalette::_buildMap()
{
    //                                      Light (Outdoor)       Dark (Indoor)
    //                                      Disabled   Enabled    Disabled   Enabled
    DECLARE_QGC_COLOR(window,               "#0F0F12", "#18181B", "#0F0F12", "#18181B")
    DECLARE_QGC_COLOR(windowTransparent,    "#cc0F0F12", "#cc18181B", "#cc0F0F12", "#cc18181B")
    DECLARE_QGC_COLOR(windowShadeLight,     "#3F3F46", "#3F3F46", "#3F3F46", "#3F3F46")
    DECLARE_QGC_COLOR(windowShade,          "#1E1E22", "#1E1E22", "#1E1E22", "#1E1E22")
    DECLARE_QGC_COLOR(windowShadeDark,      "#121214", "#121214", "#121214", "#121214")
    DECLARE_QGC_COLOR(text,                 "#71717A", "#F4F4F5", "#71717A", "#F4F4F5")
    DECLARE_QGC_COLOR(warningText,          "#EF4444", "#EF4444", "#EF4444", "#EF4444")
    DECLARE_QGC_COLOR(button,               "#1E1E22", "#222226", "#1E1E22", "#222226")
    DECLARE_QGC_COLOR(buttonBorder,         "#2E2E33", "#3F3F46", "#2E2E33", "#3F3F46")
    DECLARE_QGC_COLOR(buttonText,           "#71717A", "#F4F4F5", "#71717A", "#F4F4F5")
    DECLARE_QGC_COLOR(buttonHighlight,      "#27272A", "#F97316", "#27272A", "#F97316")
    DECLARE_QGC_COLOR(buttonHighlightText,  "#F4F4F5", "#FFFFFF", "#F4F4F5", "#FFFFFF")
    DECLARE_QGC_COLOR(primaryButton,        "#C2410C", "#F97316", "#C2410C", "#F97316")
    DECLARE_QGC_COLOR(primaryButtonText,    "#A1A1AA", "#FFFFFF", "#A1A1AA", "#FFFFFF")
    DECLARE_QGC_COLOR(textField,            "#18181B", "#1E1E22", "#18181B", "#1E1E22")
    DECLARE_QGC_COLOR(textFieldText,        "#71717A", "#F4F4F5", "#71717A", "#F4F4F5")
    DECLARE_QGC_COLOR(mapButton,            "#141416", "#18181B", "#141416", "#18181B")
    DECLARE_QGC_COLOR(mapButtonHighlight,   "#27272A", "#F97316", "#27272A", "#F97316")
    DECLARE_QGC_COLOR(mapIndicator,         "#C2410C", "#F97316", "#C2410C", "#F97316")
    DECLARE_QGC_COLOR(mapIndicatorChild,    "#2A160A", "#C2410C", "#2A160A", "#C2410C")
    DECLARE_QGC_COLOR(colorGreen,           "#16A34A", "#22C55E", "#16A34A", "#22C55E")
    DECLARE_QGC_COLOR(colorYellow,          "#D97706", "#F59E0B", "#D97706", "#F59E0B")
    DECLARE_QGC_COLOR(colorYellowGreen,     "#65A30D", "#84CC16", "#65A30D", "#84CC16")
    DECLARE_QGC_COLOR(colorOrange,          "#C2410C", "#F97316", "#C2410C", "#F97316")
    DECLARE_QGC_COLOR(colorRed,             "#DC2626", "#EF4444", "#DC2626", "#EF4444")
    DECLARE_QGC_COLOR(colorGrey,            "#71717A", "#A1A1AA", "#71717A", "#A1A1AA")
    DECLARE_QGC_COLOR(colorBlue,            "#0284C7", "#38BDF8", "#0284C7", "#38BDF8")
    DECLARE_QGC_COLOR(alertBackground,      "#D97706", "#F59E0B", "#D97706", "#F59E0B")
    DECLARE_QGC_COLOR(alertBorder,          "#2E2E33", "#3F3F46", "#2E2E33", "#3F3F46")
    DECLARE_QGC_COLOR(alertText,            "#0C0A09", "#0C0A09", "#0C0A09", "#0C0A09")
    DECLARE_QGC_COLOR(missionItemEditor,    "#1E1E22", "#222226", "#1E1E22", "#222226")
    DECLARE_QGC_COLOR(toolStripHoverColor,  "#222226", "#27272A", "#222226", "#27272A")
    DECLARE_QGC_COLOR(statusFailedText,     "#71717A", "#F4F4F5", "#71717A", "#F4F4F5")
    DECLARE_QGC_COLOR(statusPassedText,     "#71717A", "#F4F4F5", "#71717A", "#F4F4F5")
    DECLARE_QGC_COLOR(statusPendingText,    "#71717A", "#F4F4F5", "#71717A", "#F4F4F5")
    DECLARE_QGC_COLOR(toolbarBackground,    "#000F0F12", "#0018181B", "#000F0F12", "#0018181B")
    DECLARE_QGC_COLOR(groupBorder,          "#2E2E33", "#3F3F46", "#2E2E33", "#3F3F46")
    DECLARE_QGC_COLOR(modifiedParamValue,   "#C2410C", "#F97316", "#C2410C", "#F97316")

    // Colors not affecting by theming
    //                                                      Disabled     Enabled
    DECLARE_QGC_NONTHEMED_COLOR(brandingPurple,             "#1E1E22", "#F97316")
    DECLARE_QGC_NONTHEMED_COLOR(brandingBlue,               "#C2410C", "#F97316")
    DECLARE_QGC_NONTHEMED_COLOR(toolStripFGColor,           "#71717A", "#F4F4F5")
    DECLARE_QGC_NONTHEMED_COLOR(photoCaptureButtonColor,    "#71717A", "#F4F4F5")
    DECLARE_QGC_NONTHEMED_COLOR(videoCaptureButtonColor,    "#f89a9e", "#EF4444")

    // Colors not affecting by theming or enable/disable
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderLight,          "#ffffff")
    DECLARE_QGC_SINGLE_COLOR(mapWidgetBorderDark,           "#000000")
    DECLARE_QGC_SINGLE_COLOR(mapMissionTrajectory,          "#F97316")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonInterior,         "#22C55E")
    DECLARE_QGC_SINGLE_COLOR(surveyPolygonTerrainCollision, "#EF4444")

}

void QGCPalette::setColorGroupEnabled(bool enabled)
{
    _colorGroupEnabled = enabled;
    emit paletteChanged();
}

void QGCPalette::setGlobalTheme(Theme newTheme)
{
    // Mobile build does not have themes
    if (_theme != newTheme) {
        _theme = newTheme;
        _signalPaletteChangeToAll();
    }
}

void QGCPalette::_signalPaletteChangeToAll()
{
    // Notify all objects of the new theme
    for (QGCPalette *palette : std::as_const(_paletteObjects)) {
        palette->_signalPaletteChanged();
    }
}

void QGCPalette::_signalPaletteChanged()
{
    emit paletteChanged();
}
