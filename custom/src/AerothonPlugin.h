#pragma once

#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"

class QQmlApplicationEngine;
class LinkInterface;

class AerothonOverrideInterceptor final : public QQmlAbstractUrlInterceptor
{
public:
    QUrl intercept(const QUrl &url, DataType type) final;
};

class AerothonPlugin final : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit AerothonPlugin(QObject *parent = nullptr);
    static QGCCorePlugin *instance();

    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) final;
    void destroyQmlApplicationEngine(QQmlApplicationEngine *engine) final;

    /// Forward AEROTHON MAVLink messages (IDs 61000-61005) to AeroTHONManager.
    /// Returns true so QGC continues processing the message normally.
    bool mavlinkMessage(Vehicle *vehicle, LinkInterface *link, const mavlink_message_t &message) final;
    void paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo) final;

private:
    QQmlApplicationEngine *_engine = nullptr;
    AerothonOverrideInterceptor *_interceptor = nullptr;
};
