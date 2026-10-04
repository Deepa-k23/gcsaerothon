#pragma once

#include <QtCore/QObject>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

class Vehicle;

/// AeroTHON audio coordinator for voice alerts and periodic altitude announcements.
///
/// This class bridges QGC's AudioOutput system with AeroTHON-specific requirements:
/// - Speaks WARNING/ERROR/CRITICAL vehicle status messages
/// - Announces altitude every 4 seconds while armed and flying
/// - Survives QML page navigation (C++ singleton, not QML-owned)
class AeroAudioCoordinator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool altitudeAnnouncementsEnabled READ altitudeAnnouncementsEnabled WRITE setAltitudeAnnouncementsEnabled NOTIFY altitudeAnnouncementsEnabledChanged)
    Q_PROPERTY(int altitudeIntervalSeconds READ altitudeIntervalSeconds WRITE setAltitudeIntervalSeconds NOTIFY altitudeIntervalSecondsChanged)

public:
    explicit AeroAudioCoordinator(QObject *parent = nullptr);
    ~AeroAudioCoordinator() override;

    static AeroAudioCoordinator *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool enabled() const { return _enabled; }
    void setEnabled(bool enabled);

    bool altitudeAnnouncementsEnabled() const { return _altitudeEnabled; }
    void setAltitudeAnnouncementsEnabled(bool enabled);

    int altitudeIntervalSeconds() const { return _altitudeIntervalMs / 1000; }
    void setAltitudeIntervalSeconds(int seconds);

    Q_INVOKABLE void announceText(const QString &text, const QString &severity);

signals:
    void enabledChanged();
    void altitudeAnnouncementsEnabledChanged();
    void altitudeIntervalSecondsChanged();

private slots:
    void _onActiveVehicleChanged(QObject *vehicleObj);
    void _onAltitudeAnnouncementTimerFired();
    void _onVehicleArmedChanged(bool armed);
    void _onTextMessageReceived(int sysid, int componentid, int severity, QString text, QString description);

private:
    void _startAltitudeTimer();
    void _stopAltitudeTimer();

    bool _enabled = true;
    bool _altitudeEnabled = true;
    int _altitudeIntervalMs = 4000;
    QTimer _altitudeTimer;
    Vehicle *_vehicle = nullptr;
};
