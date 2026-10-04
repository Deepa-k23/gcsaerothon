#include "AeroAudioCoordinator.h"

#include <QtCore/QLoggingCategory>
#include <QtQml/QQmlEngine>

#include "AudioOutput.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"

Q_LOGGING_CATEGORY(AeroAudioCoordinatorLog, "AeroTHON.AudioCoordinator")

AeroAudioCoordinator::AeroAudioCoordinator(QObject *parent)
    : QObject(parent)
{
    _altitudeTimer.setSingleShot(false);
    _altitudeTimer.setInterval(_altitudeIntervalMs);
    connect(&_altitudeTimer, &QTimer::timeout, this, &AeroAudioCoordinator::_onAltitudeAnnouncementTimerFired);

    MultiVehicleManager *mgr = MultiVehicleManager::instance();
    connect(mgr, &MultiVehicleManager::activeVehicleChanged, this, &AeroAudioCoordinator::_onActiveVehicleChanged);
    _onActiveVehicleChanged(mgr->activeVehicle());
}

AeroAudioCoordinator::~AeroAudioCoordinator()
{
    _stopAltitudeTimer();
}

AeroAudioCoordinator *AeroAudioCoordinator::create(QQmlEngine *qmlEngine, QJSEngine *)
{
    AeroAudioCoordinator *instance = new AeroAudioCoordinator(qmlEngine);
    // QML takes ownership as singleton
    QQmlEngine::setObjectOwnership(instance, QQmlEngine::CppOwnership);
    return instance;
}

void AeroAudioCoordinator::setEnabled(bool enabled)
{
    if (_enabled != enabled) {
        _enabled = enabled;
        emit enabledChanged();

        if (!_enabled) {
            _stopAltitudeTimer();
        } else if (_vehicle && _vehicle->armed()) {
            _startAltitudeTimer();
        }
    }
}

void AeroAudioCoordinator::setAltitudeAnnouncementsEnabled(bool enabled)
{
    if (_altitudeEnabled != enabled) {
        _altitudeEnabled = enabled;
        emit altitudeAnnouncementsEnabledChanged();

        if (!_altitudeEnabled) {
            _stopAltitudeTimer();
        } else if (_enabled && _vehicle && _vehicle->armed()) {
            _startAltitudeTimer();
        }
    }
}

void AeroAudioCoordinator::setAltitudeIntervalSeconds(int seconds)
{
    int ms = qBound(1, seconds, 60) * 1000;
    if (_altitudeIntervalMs != ms) {
        _altitudeIntervalMs = ms;
        _altitudeTimer.setInterval(_altitudeIntervalMs);
        emit altitudeIntervalSecondsChanged();
    }
}

void AeroAudioCoordinator::announceText(const QString &text, const QString &severity)
{
    if (!_enabled || text.isEmpty()) {
        return;
    }

    AudioOutput *audio = AudioOutput::instance();
    if (!audio || !audio->available()) {
        return;
    }

    if (severity == QStringLiteral("WARNING") || severity == QStringLiteral("ERROR") || severity == QStringLiteral("CRITICAL")) {
        audio->sayAlert(text);
    } else {
        audio->say(text);
    }
}

void AeroAudioCoordinator::_onActiveVehicleChanged(QObject *vehicleObj)
{
    if (_vehicle) {
        disconnect(_vehicle, nullptr, this, nullptr);
    }

    _vehicle = qobject_cast<Vehicle*>(vehicleObj);

    if (_vehicle) {
        connect(_vehicle, &Vehicle::armedChanged, this, &AeroAudioCoordinator::_onVehicleArmedChanged);
        connect(_vehicle, &Vehicle::textMessageReceived, this, &AeroAudioCoordinator::_onTextMessageReceived);
        if (_vehicle->armed()) {
            _startAltitudeTimer();
        }
    } else {
        _stopAltitudeTimer();
    }
}

void AeroAudioCoordinator::_onVehicleArmedChanged(bool armed)
{
    if (armed) {
        _startAltitudeTimer();
    } else {
        _stopAltitudeTimer();
    }
}

void AeroAudioCoordinator::_onTextMessageReceived(int, int, int severity, QString text, QString)
{
    if (!_enabled || text.isEmpty()) {
        return;
    }

    AudioOutput *audio = AudioOutput::instance();
    if (!audio || !audio->available()) {
        return;
    }

    // MAVLink severity levels: 0=EMERGENCY, 1=ALERT, 2=CRITICAL, 3=ERROR, 4=WARNING, 5=NOTICE, 6=INFO, 7=DEBUG
    // Speak WARNING (4) and higher-priority messages
    if (severity <= 4) {
        audio->sayAlert(text);
    }
}

void AeroAudioCoordinator::_onAltitudeAnnouncementTimerFired()
{
    if (!_enabled || !_altitudeEnabled || !_vehicle || !_vehicle->armed()) {
        _stopAltitudeTimer();
        return;
    }

    AudioOutput *audio = AudioOutput::instance();
    if (!audio || !audio->available()) {
        return;
    }

    Fact *altFact = _vehicle->altitudeRelative();
    if (!altFact) {
        return;
    }

    QVariant altVal = altFact->rawValue();
    if (!altVal.isValid()) {
        return;
    }

    double altMeters = altVal.toDouble();
    QString announcement = QStringLiteral("Altitude %1 meters").arg(qRound(altMeters));
    audio->sayPeriodic(announcement);
}

void AeroAudioCoordinator::_startAltitudeTimer()
{
    if (!_enabled || !_altitudeEnabled || !_vehicle || !_vehicle->armed()) {
        return;
    }

    if (!_altitudeTimer.isActive()) {
        qCDebug(AeroAudioCoordinatorLog) << "Starting altitude announcements";
        _altitudeTimer.start();
    }
}

void AeroAudioCoordinator::_stopAltitudeTimer()
{
    if (_altitudeTimer.isActive()) {
        qCDebug(AeroAudioCoordinatorLog) << "Stopping altitude announcements";
        _altitudeTimer.stop();
    }
}
