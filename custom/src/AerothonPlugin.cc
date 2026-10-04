#include "AerothonPlugin.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtCore/QHash>
#include <QtGui/QColor>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/qqmlextensionplugin.h>

#include "AeroTHONManager.h"
#include "AeroAlertModel.h"
#include "AeroMessageModel.h"
#include "AeroDetectionEventModel.h"
#include "AeroOperationalHealth.h"
#include "AeroSessionRecorder.h"
#include "AeroVideoReceiver.h"
#include "AeroAudioCoordinator.h"

// ---------------------------------------------------------------------------
// Singleton instance
// ---------------------------------------------------------------------------

Q_APPLICATION_STATIC(AerothonPlugin, aerothonPluginInstance);

AerothonPlugin::AerothonPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
}

QGCCorePlugin *AerothonPlugin::instance()
{
    return aerothonPluginInstance();
}

// ---------------------------------------------------------------------------
// QML engine lifecycle
// ---------------------------------------------------------------------------

QQmlApplicationEngine *AerothonPlugin::createQmlApplicationEngine(QObject *parent)
{
    // The custom settings Facts are constructed by singleton registration
    // below. Explicit initialization avoids static-order differences between
    // build-tree and packaged executables.
    Q_INIT_RESOURCE(custom);
    _engine = QGCCorePlugin::createQmlApplicationEngine(parent);

    // Install URL interceptor so custom QML files shadow stock QGC files.
    _interceptor = new AerothonOverrideInterceptor;
    _engine->addUrlInterceptor(_interceptor);

    // Register AeroTHON singletons and elements so QML can access them via
    // import AeroTHON (or the module declared in CMakeLists / qmldir).
    qmlRegisterSingletonInstance<AeroTHONManager>(
        "AeroTHON", 1, 0, "AeroTHONManager", AeroTHONManager::instance());


    qmlRegisterSingletonInstance<AeroMessageModel>(
        "AeroTHON", 1, 0, "AeroMessageModel", AeroMessageModel::instance());
    qmlRegisterSingletonInstance<AeroAlertModel>(
        "AeroTHON", 1, 0, "AeroAlertModel", AeroAlertModel::instance());
    qmlRegisterSingletonInstance<AeroDetectionEventModel>(
        "AeroTHON", 1, 0, "AeroDetectionEventModel", AeroDetectionEventModel::instance());
    qmlRegisterSingletonInstance<AeroOperationalHealth>(
        "AeroTHON", 1, 0, "AeroOperationalHealth", AeroOperationalHealth::instance());
    qmlRegisterSingletonInstance<AeroSessionRecorder>(
        "AeroTHON", 1, 0, "AeroSessionRecorder", AeroSessionRecorder::instance());
    qmlRegisterType<AeroVideoReceiver>("AeroTHON", 1, 0, "AeroVideoReceiver");

    qmlRegisterSingletonInstance<AeroAudioCoordinator>(
        "AeroTHON", 1, 0, "AeroAudioCoordinator", AeroAudioCoordinator::create(_engine, nullptr));

    return _engine;
}

void AerothonPlugin::destroyQmlApplicationEngine(QQmlApplicationEngine *engine)
{
    if (engine && engine == _engine) {
        engine->removeUrlInterceptor(_interceptor);
        delete _interceptor;
        _interceptor = nullptr;
        _engine = nullptr;
    }
    QGCCorePlugin::destroyQmlApplicationEngine(engine);
}

// ---------------------------------------------------------------------------
// MAVLink message interception
// ---------------------------------------------------------------------------

bool AerothonPlugin::mavlinkMessage(Vehicle *vehicle, LinkInterface *link,
                                     const mavlink_message_t &message)
{
    Q_UNUSED(link)

    // Forward AEROTHON custom messages (IDs 61000–61006) to the manager.
    // Return true so QGC can also process them if needed.
    constexpr quint32 kAerothonMsgFirst = 61000;
    constexpr quint32 kAerothonMsgLast = 61006;

    if (message.msgid >= kAerothonMsgFirst && message.msgid <= kAerothonMsgLast) {
        AeroTHONManager::instance()->handleAerothonMessage(vehicle, message);
        return true; // allow QGC to continue processing
    }

    return true;
}

void AerothonPlugin::paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo)
{
    // Centralized QGC palette bridge: native Plan, Vehicle Setup, Parameters,
    // Analyze, and Settings controls keep their real implementations while
    // adopting the AeroTHON product surfaces and semantic colors.
    static const QHash<QString, QColor> overrides = {
        {QStringLiteral("window"), QColor(QStringLiteral("#0F0F12"))},
        {QStringLiteral("windowTransparent"), QColor(QStringLiteral("#cc18181B"))},
        {QStringLiteral("windowShadeLight"), QColor(QStringLiteral("#3F3F46"))},
        {QStringLiteral("windowShade"), QColor(QStringLiteral("#18181B"))},
        {QStringLiteral("windowShadeDark"), QColor(QStringLiteral("#121214"))},
        {QStringLiteral("text"), QColor(QStringLiteral("#F4F4F5"))},
        {QStringLiteral("button"), QColor(QStringLiteral("#1E1E22"))},
        {QStringLiteral("buttonBorder"), QColor(QStringLiteral("#3F3F46"))},
        {QStringLiteral("buttonText"), QColor(QStringLiteral("#F4F4F5"))},
        {QStringLiteral("buttonHighlight"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("buttonHighlightText"), QColor(QStringLiteral("#FFFFFF"))},
        {QStringLiteral("primaryButton"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("primaryButtonText"), QColor(QStringLiteral("#FFFFFF"))},
        {QStringLiteral("textField"), QColor(QStringLiteral("#1E1E22"))},
        {QStringLiteral("textFieldText"), QColor(QStringLiteral("#F4F4F5"))},
        {QStringLiteral("toolbarBackground"), QColor(QStringLiteral("#18181B"))},
        {QStringLiteral("groupBorder"), QColor(QStringLiteral("#3F3F46"))},
        {QStringLiteral("brandingBlue"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("brandingPurple"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("colorGreen"), QColor(QStringLiteral("#22C55E"))},
        {QStringLiteral("colorYellow"), QColor(QStringLiteral("#F59E0B"))},
        {QStringLiteral("colorOrange"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("colorRed"), QColor(QStringLiteral("#EF4444"))},
        {QStringLiteral("colorBlue"), QColor(QStringLiteral("#38BDF8"))},
        {QStringLiteral("alertBackground"), QColor(QStringLiteral("#3B1212"))},
        {QStringLiteral("alertBorder"), QColor(QStringLiteral("#EF4444"))},
        {QStringLiteral("alertText"), QColor(QStringLiteral("#F4F4F5"))},
        {QStringLiteral("missionItemEditor"), QColor(QStringLiteral("#222226"))},
        {QStringLiteral("mapButton"), QColor(QStringLiteral("#18181B"))},
        {QStringLiteral("mapButtonHighlight"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("mapIndicator"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("mapIndicatorChild"), QColor(QStringLiteral("#C2410C"))},
        {QStringLiteral("modifiedParamValue"), QColor(QStringLiteral("#F97316"))},
        {QStringLiteral("warningText"), QColor(QStringLiteral("#EF4444"))},
    };

    const auto it = overrides.constFind(colorName);
    if (it == overrides.cend()) {
        return;
    }

    for (int theme = 0; theme < QGCPalette::cMaxTheme; ++theme) {
        colorInfo[theme][QGCPalette::ColorGroupEnabled] = *it;
        colorInfo[theme][QGCPalette::ColorGroupDisabled] = it->darker(150);
    }
}

// ---------------------------------------------------------------------------
// URL interceptor
// ---------------------------------------------------------------------------

QUrl AerothonOverrideInterceptor::intercept(const QUrl &url, DataType type)
{
    if ((type == QmlFile || type == UrlString) && url.scheme() == QStringLiteral("qrc")) {
        const QString overridePath = QStringLiteral(":/Custom%1").arg(url.path());
        if (QFile::exists(overridePath)) {
            QUrl result;
            result.setScheme(QStringLiteral("qrc"));
            result.setPath('/' + overridePath.mid(2));
            return result;
        }
    }
    return url;
}
