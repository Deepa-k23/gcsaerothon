#include "AeroTHONManager.h"
#include "AeroTHONSettings.h"
#include "AeroAlertModel.h"
#include "AppMessages.h"
#include "AudioOutput.h"
#include "Fact.h"
#include "MissionManager.h"
#include "MultiVehicleManager.h"
#include "VehicleLinkManager.h"

#include <optional>
#include <QtCore/QDateTime>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QLoggingCategory>
#include <QtNetwork/QNetworkRequest>
#include <QtQml/QQmlEngine>

#include "Vehicle.h"

#include <cmath>

Q_LOGGING_CATEGORY(AeroTHONManagerLog, "AeroTHON.Manager")

// ---------------------------------------------------------------------------
// Singleton
// ---------------------------------------------------------------------------

AeroTHONManager *AeroTHONManager::instance()
{
    static AeroTHONManager manager;
    return &manager;
}

AeroTHONManager *AeroTHONManager::create(QQmlEngine *qmlEngine, QJSEngine *jsEngine)
{
    Q_UNUSED(qmlEngine)
    Q_UNUSED(jsEngine)

    AeroTHONManager *manager = instance();
    QQmlEngine::setObjectOwnership(manager, QQmlEngine::CppOwnership);
    return manager;
}

// ---------------------------------------------------------------------------
// Constructor
// ---------------------------------------------------------------------------

AeroTHONManager::AeroTHONManager(QObject *parent)
    : QObject(parent)
{
    // 1 Hz display update gate
    _displayTimer.setInterval(1000);
    _displayTimer.setSingleShot(false);
    connect(&_displayTimer, &QTimer::timeout, this, &AeroTHONManager::_onDisplayTimer);
    _displayTimer.start();

    // 1 Hz Flask polling timer (doesn't start until startFlaskPolling() is called)
    _pollTimer.setInterval(1000);
    _pollTimer.setSingleShot(false);
    connect(&_pollTimer, &QTimer::timeout, this, &AeroTHONManager::_onFlaskPollTimer);
    connect(_settings.reduceMotion(), &Fact::rawValueChanged, this, &AeroTHONManager::reduceMotionChanged);
    connect(AudioOutput::instance(), &AudioOutput::availableChanged,
            this, &AeroTHONManager::voiceAvailableChanged);

    MultiVehicleManager *multiVehicleManager = MultiVehicleManager::instance();
    connect(multiVehicleManager, &MultiVehicleManager::activeVehicleChanged,
            this, &AeroTHONManager::_setActiveVehicle);
    _setActiveVehicle(multiVehicleManager->activeVehicle());
}

bool AeroTHONManager::voiceAvailable() const
{
    return AudioOutput::instance()->available();
}

// ---------------------------------------------------------------------------
// Flask polling control
// ---------------------------------------------------------------------------

void AeroTHONManager::startFlaskPolling()
{
    if (!_pollTimer.isActive()) {
        qCInfo(AeroTHONManagerLog) << "Flask polling started";
        _pollTimer.start(qMax(250, _settings.axonPollInterval()->rawValue().toInt()));
    }
}

void AeroTHONManager::stopFlaskPolling()
{
    if (_pollTimer.isActive()) {
        _pollTimer.stop();
        qCInfo(AeroTHONManagerLog) << "Flask polling stopped";
    }
    // Abort any in-flight request
    if (_pendingReply) {
        _pendingReply->abort();
        _pendingReply = nullptr;
    }
}

// ---------------------------------------------------------------------------
// Mission quick action
// ---------------------------------------------------------------------------

void AeroTHONManager::startNativeMission()
{
    Vehicle *vehicle = _activeVehicle;
    if (!vehicle) {
        AeroAlertModel::instance()->raiseAlert(
            QStringLiteral("MISSION:start-nodrive"),
            QStringLiteral("WARNING"), QStringLiteral("MISSION"),
            QStringLiteral("No vehicle connected"));
        return;
    }

    MissionManager *mm = vehicle->missionManager();
    if (!mm || mm->missionItems().isEmpty()) {
        AeroAlertModel::instance()->raiseAlert(
            QStringLiteral("MISSION:start-nomission"),
            QStringLiteral("WARNING"), QStringLiteral("MISSION"),
            QStringLiteral("No mission loaded"),
            QStringLiteral("Plan and upload a mission first"));
        QGC::showAppMessage(tr("No mission available. Plan and upload a mission first."));
        return;
    }

    // Validate that a mission is present in the MissionManager
    qCInfo(AeroTHONManagerLog) << "Starting native mission with" << mm->missionItems().size() << "items";
    AeroAlertModel::instance()->raiseAlert(
        QStringLiteral("MISSION:start-request"),
        QStringLiteral("SYSTEM"), QStringLiteral("MISSION"),
        QStringLiteral("Starting mission"),
        QStringLiteral("%1 mission items").arg(mm->missionItems().size()));

    // Delegate to the native QGC PX4 safety-gated path.
    // This sets AUTO.MISSION mode and arms, with all firmware-level validation.
    vehicle->startMission();
}

// ---------------------------------------------------------------------------
// Timers
// ---------------------------------------------------------------------------

void AeroTHONManager::_onDisplayTimer()
{
    // Drive the connection state machine on every tick
    _updateAxonState();
    _expireStaleWfb();
    _updateMissionTiming();
    _updateAltitudeAnnouncement();
    emit displayUpdateReady();
}

void AeroTHONManager::_setActiveVehicle(Vehicle *vehicle)
{
    if (_activeVehicle == vehicle) {
        return;
    }
    if (_activeVehicle) {
        disconnect(_activeVehicle, nullptr, this, nullptr);
        if (_activeVehicle->missionManager()) {
            disconnect(_activeVehicle->missionManager(), nullptr, this, nullptr);
        }
    }

    _activeVehicle = vehicle;
    _missionTimingActive = false;
    _missionTimingStarted = false;
    _missionElapsedSeconds = 0;
    _missionAccumulatedMs = 0;
    _missionActiveClock.invalidate();
    _altitudeAnnouncementClock.invalidate();
    emit missionTimingActiveChanged();
    emit missionElapsedSecondsChanged();

    if (!_activeVehicle) {
        return;
    }

    connect(_activeVehicle, &Vehicle::armedChanged, this, &AeroTHONManager::_updateMissionTiming);
    connect(_activeVehicle, &Vehicle::flyingChanged, this, &AeroTHONManager::_updateMissionTiming);
    connect(_activeVehicle, &Vehicle::flightModeChanged, this, &AeroTHONManager::_updateMissionTiming);
    if (_activeVehicle->missionManager()) {
        connect(_activeVehicle->missionManager(), &MissionManager::currentIndexChanged,
                this, &AeroTHONManager::_updateMissionTiming);
    }
    _updateMissionTiming();
}

void AeroTHONManager::_updateMissionTiming()
{
    const bool vehicleArmed = _activeVehicle && _activeVehicle->armed();
    const bool vehicleFlying = vehicleArmed && _activeVehicle->flying();
    const QString missionMode = _activeVehicle ? _activeVehicle->missionFlightMode() : QString();
    const bool inMissionMode = vehicleFlying && !missionMode.isEmpty() && _activeVehicle->flightMode() == missionMode;
    const bool hasMissionIndex = _activeVehicle && _activeVehicle->missionManager()
                                 && _activeVehicle->missionManager()->currentIndex() >= 0;
    const bool companionReportsComplete = _missionState == QStringLiteral("COMPLETE");
    const bool shouldRun = inMissionMode && hasMissionIndex && !companionReportsComplete;

    if (shouldRun && !_missionTimingStarted) {
        _missionTimingStarted = true;
        _missionAccumulatedMs = 0;
        if (_missionElapsedSeconds != 0) {
            _missionElapsedSeconds = 0;
            emit missionElapsedSecondsChanged();
        }
    }

    if (shouldRun && !_missionTimingActive) {
        _missionTimingActive = true;
        _missionActiveClock.restart();
        emit missionTimingActiveChanged();
    } else if (!shouldRun && _missionTimingActive) {
        _missionAccumulatedMs += _missionActiveClock.elapsed();
        _missionActiveClock.invalidate();
        _missionTimingActive = false;
        emit missionTimingActiveChanged();
    }

    if (!vehicleArmed) {
        _missionTimingStarted = false;
    }

    const qint64 elapsedMs = _missionAccumulatedMs
        + (_missionTimingActive && _missionActiveClock.isValid() ? _missionActiveClock.elapsed() : 0);
    const quint64 elapsedSeconds = static_cast<quint64>(qMax<qint64>(0, elapsedMs) / 1000);
    if (_missionElapsedSeconds != elapsedSeconds) {
        _missionElapsedSeconds = elapsedSeconds;
        emit missionElapsedSecondsChanged();
    }
}

void AeroTHONManager::_updateAltitudeAnnouncement()
{
    const bool flying = _activeVehicle && _activeVehicle->flying()
                        && !_activeVehicle->vehicleLinkManager()->communicationLost();
    if (!flying || !_settings.altitudeAnnouncements()->rawValue().toBool()) {
        _altitudeAnnouncementClock.invalidate();
        return;
    }

    const qint64 intervalMs = qMax(1, _settings.altitudeAnnouncementInterval()->rawValue().toInt()) * 1000LL;
    if (!_altitudeAnnouncementClock.isValid()) {
        _altitudeAnnouncementClock.start();
        return;
    }
    if (_altitudeAnnouncementClock.elapsed() < intervalMs) {
        return;
    }
    _altitudeAnnouncementClock.restart();

    Fact *altitudeFact = _activeVehicle->altitudeRelative();
    if (!altitudeFact) {
        return;
    }
    const double altitude = altitudeFact->cookedValue().toDouble();
    if (!std::isfinite(altitude)) {
        return;
    }

    QString units = altitudeFact->cookedUnits().trimmed();
    if (units.isEmpty()) {
        units = QStringLiteral("meters");
    }
    AudioOutput::instance()->sayPeriodic(tr("Altitude %1 %2").arg(qRound(altitude)).arg(units));
}

void AeroTHONManager::_onFlaskPollTimer()
{
    // Don't stack requests
    if (_pendingReply) {
        return;
    }

    const QString host = _settings.axonHost()->rawValue().toString();
    if (host.isEmpty()) {
        return;
    }
    const int port = _settings.axonPort()->rawValue().toInt();
    const int readTimeoutMs = _settings.axonReadTimeout()->rawValue().toInt();

    const QUrl url(QStringLiteral("http://%1:%2/api/v1/health").arg(host).arg(port));
    QNetworkRequest request(url);
    request.setTransferTimeout(readTimeoutMs);

    _pendingReply = _nam.get(request);
    connect(_pendingReply, &QNetworkReply::finished,
            this, &AeroTHONManager::_onFlaskReplyFinished);
}

void AeroTHONManager::_onFlaskReplyFinished()
{
    QNetworkReply *reply = _pendingReply;
    _pendingReply = nullptr;

    if (!reply) {
        return;
    }

    reply->deleteLater();

    if (reply->error() != QNetworkReply::NoError) {
        qCWarning(AeroTHONManagerLog) << "Flask request error:" << reply->errorString();
        // Don't update _lastFlaskResponseMs — state machine will degrade/lose
        return;
    }

    const QByteArray data = reply->readAll();
    _lastFlaskResponseMs = QDateTime::currentMSecsSinceEpoch();
    _parseFlaskJson(data);
}

// ---------------------------------------------------------------------------
// Flask JSON parser
// ---------------------------------------------------------------------------

void AeroTHONManager::_parseFlaskJson(const QByteArray &data)
{
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        qCWarning(AeroTHONManagerLog) << "Invalid JSON from Flask:" << err.errorString();
        return;
    }

    const QJsonObject obj = doc.object();

    // ── system section ────────────────────────────────────────────────────────
    // Supports both nested {"system":{"cpu_pct":...}} and flat {"cpu_pct":...}
    // for compatibility with different Flask versions / mock servers.
    auto readFloat = [&](const QJsonObject &o, const QString &key) -> std::optional<float> {
        if (o.contains(key) && !o[key].isNull())
            return static_cast<float>(o[key].toDouble());
        return std::nullopt;
    };
    auto readInt = [&](const QJsonObject &o, const QString &key) -> std::optional<int> {
        if (o.contains(key) && !o[key].isNull())
            return o[key].toInt();
        return std::nullopt;
    };
    auto readStr = [&](const QJsonObject &o, const QString &key) -> std::optional<QString> {
        if (o.contains(key) && o[key].isString())
            return o[key].toString();
        return std::nullopt;
    };

    const QJsonObject sysObj  = obj.contains(QStringLiteral("system"))  ? obj[QStringLiteral("system")].toObject()  : obj;
    const QJsonObject wfbObj  = obj.contains(QStringLiteral("wfb"))     ? obj[QStringLiteral("wfb")].toObject()     : obj;
    const QJsonObject camObj  = obj.contains(QStringLiteral("cameras")) ? obj[QStringLiteral("cameras")].toObject() : QJsonObject{};
    const QJsonObject visObj  = obj.contains(QStringLiteral("vision"))  ? obj[QStringLiteral("vision")].toObject()  : obj;
    const QJsonObject fpvObj  = camObj.contains(QStringLiteral("fpv"))  ? camObj[QStringLiteral("fpv")].toObject()  : QJsonObject{};
    const QJsonObject nadrObj = camObj.contains(QStringLiteral("nadir"))? camObj[QStringLiteral("nadir")].toObject(): QJsonObject{};

    if (auto v = readFloat(sysObj, QStringLiteral("cpu_pct")))       _setAndNotify(_cpuPct,       *v, &AeroTHONManager::cpuPctChanged);
    if (auto v = readFloat(sysObj, QStringLiteral("ram_pct")))       _setAndNotify(_ramPct,       *v, &AeroTHONManager::ramPctChanged);
    if (auto v = readFloat(sysObj, QStringLiteral("temp_c")))        _setAndNotify(_tempC,        *v, &AeroTHONManager::tempCChanged);
    if (auto v = readFloat(sysObj, QStringLiteral("storage_free_gib")))  {
        // Convert GiB → MiB for internal storage
        _setAndNotify(_storageMib, (*v) * 1024.0f, &AeroTHONManager::storageMibChanged);
    }
    // Camera FPS from nested cameras.fpv.fps / cameras.nadir.fps
    if (auto v = readFloat(fpvObj,  QStringLiteral("fps")))          _setAndNotify(_fpvFps,       *v, &AeroTHONManager::fpvFpsChanged);
    if (auto v = readFloat(nadrObj, QStringLiteral("fps")))          _setAndNotify(_nadirFps,     *v, &AeroTHONManager::nadirFpsChanged);
    if (auto v = readFloat(visObj,  QStringLiteral("inference_fps")))_setAndNotify(_inferenceFps, *v, &AeroTHONManager::inferenceFpsChanged);
    if (auto v = readStr(fpvObj,    QStringLiteral("status")))       _setAndNotify(_gstreamerState, *v, &AeroTHONManager::gstreamerStateChanged);
    if (auto v = readStr(wfbObj,    QStringLiteral("status")))       _setAndNotify(_wfbTxState,   *v, &AeroTHONManager::wfbTxStateChanged);

    // WFB telemetry (nested wfb object)
    bool receivedWfb = false;
    if (auto v = readInt(wfbObj, QStringLiteral("rssi_dbm"))) {
        _setAndNotify(_rssiDbm, *v, &AeroTHONManager::rssiDbmChanged);
        _markWfbMetricAvailable(_rssiAvailable);
        receivedWfb = true;
    }
    if (auto v = readFloat(wfbObj, QStringLiteral("snr_db"))) {
        _setAndNotify(_snrDb, *v, &AeroTHONManager::snrDbChanged);
        _markWfbMetricAvailable(_snrAvailable);
        receivedWfb = true;
    }
    if (auto v = readFloat(wfbObj, QStringLiteral("packet_loss_pct"))) {
        _setAndNotify(_packetLossPct, qBound(0.0f, *v, 100.0f), &AeroTHONManager::packetLossPctChanged);
        _markWfbMetricAvailable(_packetLossAvailable);
        receivedWfb = true;
    }
    if (auto v = readFloat(wfbObj, QStringLiteral("bitrate_mbps"))) {
        _setAndNotify(_bitrateMbps, qMax(0.0f, *v), &AeroTHONManager::bitrateMbpsChanged);
        _markWfbMetricAvailable(_bitrateAvailable);
        receivedWfb = true;
    }
    if (receivedWfb) {
        _lastWfbUpdateMs = QDateTime::currentMSecsSinceEpoch();
    }
    _updateWfbState();

    // Uptime
    if (obj.contains(QStringLiteral("uptime_sec")))
        _setAndNotify(_axonUptimeSec, static_cast<quint64>(obj[QStringLiteral("uptime_sec")].toDouble()), &AeroTHONManager::axonUptimeSecChanged);
}

// ---------------------------------------------------------------------------
// MAVLink message dispatcher
// ---------------------------------------------------------------------------

void AeroTHONManager::handleAerothonMessage(Vehicle *vehicle,
                                             const mavlink_message_t &message)
{
    // Guard: vehicle pointer must be valid before we use it anywhere
    if (!vehicle) {
        qCWarning(AeroTHONManagerLog) << "handleAerothonMessage: null vehicle pointer";
        return;
    }

    switch (message.msgid) {
    case MSG_AEROTHON_HEALTH:
        _handleAerothonHealth(message);
        break;
    case MSG_AEROTHON_STATUS:
        _handleAerothonStatus(message);
        break;
    case MSG_AEROTHON_DETECTION:
        _handleAerothonDetection(message);
        break;
    case MSG_AEROTHON_QR_RESULT:
        _handleAerothonQrResult(message);
        break;
    case MSG_AEROTHON_COMMAND:
        _handleAerothonCommand(message, vehicle);
        break;
    case MSG_AEROTHON_COMMAND_ACK:
        _handleAerothonCommandAck(message);
        break;
    default:
        break;
    }
}

void AeroTHONManager::_handleAerothonHealth(const mavlink_message_t &message)
{
    mavlink_aerothon_health_t health{};
    mavlink_msg_aerothon_health_decode(&message, &health);

    static const QStringList kPipelineStates = {
        QStringLiteral("UNKNOWN"),
        QStringLiteral("RUNNING"),
        QStringLiteral("STOPPED"),
        QStringLiteral("ERROR")
    };

    _setAndNotify(_cpuPct, health.cpu_load_pct, &AeroTHONManager::cpuPctChanged);
    _setAndNotify(_ramPct, health.memory_used_pct, &AeroTHONManager::ramPctChanged);
    _setAndNotify(_tempC, health.temperature_c, &AeroTHONManager::tempCChanged);
    _setAndNotify(_storageMib, static_cast<float>(health.available_storage_mib), &AeroTHONManager::storageMibChanged);
    _setAndNotify(_fpvFps, health.front_fps, &AeroTHONManager::fpvFpsChanged);
    _setAndNotify(_nadirFps, health.nadir_fps, &AeroTHONManager::nadirFpsChanged);
    _setAndNotify(_inferenceFps, health.inference_fps, &AeroTHONManager::inferenceFpsChanged);
    _setAndNotify(_rssiDbm, static_cast<int>(health.wfb_rssi_dbm), &AeroTHONManager::rssiDbmChanged);
    _setAndNotify(_snrDb, static_cast<float>(health.wfb_snr_db), &AeroTHONManager::snrDbChanged);
    _setAndNotify(_packetLossPct, health.wfb_packet_loss_pct, &AeroTHONManager::packetLossPctChanged);
    _setAndNotify(_bitrateMbps, health.wfb_bitrate_mbps, &AeroTHONManager::bitrateMbpsChanged);
    _markWfbMetricAvailable(_rssiAvailable);
    _markWfbMetricAvailable(_snrAvailable);
    _markWfbMetricAvailable(_packetLossAvailable);
    _markWfbMetricAvailable(_bitrateAvailable);
    _lastWfbUpdateMs = QDateTime::currentMSecsSinceEpoch();
    _setAndNotify(_gstreamerState,
                  health.gstreamer_state < static_cast<quint8>(kPipelineStates.size())
                      ? kPipelineStates[health.gstreamer_state]
                      : QStringLiteral("UNKNOWN"),
                  &AeroTHONManager::gstreamerStateChanged);
    _setAndNotify(_wfbTxState,
                  health.wfb_tx_state < static_cast<quint8>(kPipelineStates.size())
                      ? kPipelineStates[health.wfb_tx_state]
                      : QStringLiteral("UNKNOWN"),
                  &AeroTHONManager::wfbTxStateChanged);
    _setAndNotify(_axonUptimeSec, static_cast<quint64>(health.uptime_ms / 1000U), &AeroTHONManager::axonUptimeSecChanged);

    _updateWfbState();

    // A health message counts as a live Axon contact
    _lastFlaskResponseMs = QDateTime::currentMSecsSinceEpoch();
}

void AeroTHONManager::_handleAerothonStatus(const mavlink_message_t &message)
{
    mavlink_aerothon_status_t status{};
    mavlink_msg_aerothon_status_decode(&message, &status);

    static const QStringList kMissionStates = {
        QStringLiteral("IDLE"), QStringLiteral("PREFLIGHT"), QStringLiteral("TAKEOFF"),
        QStringLiteral("INITIAL QR"), QStringLiteral("AREA SEARCH"), QStringLiteral("BANNER SEARCH"),
        QStringLiteral("CORRIDOR ENTRY"), QStringLiteral("CORRIDOR FLIGHT"), QStringLiteral("DELIVERY SEARCH"),
        QStringLiteral("PAYLOAD DELIVERY"), QStringLiteral("RETURN CORRIDOR"), QStringLiteral("RTL"),
        QStringLiteral("LANDING"), QStringLiteral("COMPLETE")
    };

    const QString missionState = status.state < static_cast<quint8>(kMissionStates.size())
        ? kMissionStates[status.state]
        : QStringLiteral("UNKNOWN");
    const QString activeTarget = QString::fromUtf8(status.active_target, sizeof(status.active_target)).split(QChar::Null).constFirst();
    const QString transitionReason = QString::fromUtf8(status.transition_reason, sizeof(status.transition_reason)).split(QChar::Null).constFirst();
    const bool wasComplete = _missionState == QStringLiteral("COMPLETE");

    _setAndNotify(_missionState,    missionState,    &AeroTHONManager::missionStateChanged);
    _setAndNotify(_missionProgress, static_cast<float>(status.progress_pct), &AeroTHONManager::missionProgressChanged);
    _setAndNotify(_stageElapsedMs, static_cast<quint64>(status.stage_elapsed_ms), &AeroTHONManager::stageElapsedMsChanged);
    _setAndNotify(_activeTarget,    activeTarget,    &AeroTHONManager::activeTargetChanged);
    _setAndNotify(_missionChecksum, status.mission_checksum, &AeroTHONManager::missionChecksumChanged);
    _setAndNotify(_missionResult, static_cast<int>(status.result), &AeroTHONManager::missionResultChanged);
    _setAndNotify(_routeProgress, static_cast<int>(status.route_progress_pct), &AeroTHONManager::routeProgressChanged);
    _setAndNotify(_transitionReason, transitionReason, &AeroTHONManager::transitionReasonChanged);

    if (!wasComplete && missionState == QStringLiteral("COMPLETE")) {
        if (_missionTimingActive) {
            _missionAccumulatedMs += _missionActiveClock.elapsed();
            _missionActiveClock.invalidate();
            _missionTimingActive = false;
            emit missionTimingActiveChanged();
        }
        _missionTimingStarted = false;
        _updateMissionTiming();
        emit missionCompleted();
    }
}

void AeroTHONManager::_handleAerothonDetection(const mavlink_message_t &message)
{
    mavlink_aerothon_detection_t detection{};
    mavlink_msg_aerothon_detection_decode(&message, &detection);

    _detectionId = detection.detection_id;
    _detectionType = detection.detection_type;
    _detectionCamera = detection.camera_id;
    _detectionConfidence = qBound(0.0f, detection.confidence, 1.0f);
    _detectionDistance = detection.distance;
    _detectionTimeUsec = detection.time_usec;
    emit detectionChanged();
    emit detectionReceived(_detectionId, _detectionType, _detectionCamera,
                           _detectionConfidence, _detectionDistance, _detectionTimeUsec);
}

void AeroTHONManager::_handleAerothonQrResult(const mavlink_message_t &message)
{
    mavlink_aerothon_qr_result_t result{};
    mavlink_msg_aerothon_qr_result_decode(&message, &result);

    _detectionId = result.detection_id;
    _detectionCamera = result.camera_id;
    _detectionTimeUsec = result.time_usec;
    _qrPayload = QString::fromUtf8(result.payload, sizeof(result.payload)).split(QChar::Null).constFirst();
    _qrValid = result.valid != 0;
    _qrDuplicate = result.duplicate != 0;
    emit detectionChanged();
    emit qrResultChanged();
    emit qrResultReceived(_detectionId, _qrPayload, _qrValid, _qrDuplicate,
                          _detectionCamera, _detectionTimeUsec);
}

void AeroTHONManager::_handleAerothonCommand(const mavlink_message_t &message, const Vehicle *vehicle)
{
    mavlink_aerothon_command_t command{};
    mavlink_msg_aerothon_command_decode(&message, &command);

    // A non-broadcast target must match the Vehicle through which QGC routed
    // this message. Commands remain advisory here; this path never flies or arms.
    if (command.target_system != 0 && command.target_system != vehicle->id()) {
        qCWarning(AeroTHONManagerLog) << "Ignoring AEROTHON_COMMAND for system" << command.target_system;
        return;
    }
    emit commandReceived(command.request_id, command.command, command.param1, command.param2,
                         command.target_system, command.target_component);
}

void AeroTHONManager::_handleAerothonCommandAck(const mavlink_message_t &message)
{
    mavlink_aerothon_command_ack_t ack{};
    mavlink_msg_aerothon_command_ack_decode(&message, &ack);

    _acknowledgedRequestId = ack.request_id;
    _acknowledgementResult = ack.result;
    _acknowledgementMessage = QString::fromUtf8(ack.message, sizeof(ack.message)).split(QChar::Null).constFirst();
    emit commandAcknowledged();
    emit commandAckReceived(ack.request_id, ack.command, ack.result, ack.progress_pct,
                            ack.reason_code, _acknowledgementMessage);
}


// ---------------------------------------------------------------------------
// State machines
// ---------------------------------------------------------------------------

void AeroTHONManager::_updateAxonState()
{
    if (_lastFlaskResponseMs == 0) {
        _setAndNotify(_axonState, AxonState::Unknown, &AeroTHONManager::axonStateChanged);
        return;
    }

    const qint64 ageSec = (QDateTime::currentMSecsSinceEpoch() - _lastFlaskResponseMs) / 1000;

    AxonState newState;
    if (ageSec <= 5) {
        newState = AxonState::Online;
    } else if (ageSec <= 10) {
        newState = AxonState::Degraded;
    } else {
        newState = AxonState::Lost;
    }

    _setAndNotify(_axonState, newState, &AeroTHONManager::axonStateChanged);
}

void AeroTHONManager::_updateWfbState()
{
    if (!_packetLossAvailable) {
        _setAndNotify(_wfbState, WFBState::Unknown, &AeroTHONManager::wfbStateChanged);
        return;
    }
    WFBState newState;
    if (_packetLossPct < 10.0f) {
        newState = WFBState::Normal;
    } else if (_packetLossPct < 30.0f) {
        newState = WFBState::Warning;
    } else {
        newState = WFBState::Critical;
    }
    _setAndNotify(_wfbState, newState, &AeroTHONManager::wfbStateChanged);
}

void AeroTHONManager::_markWfbMetricAvailable(bool &field)
{
    if (!field) {
        field = true;
        emit wfbAvailabilityChanged();
    }
}

void AeroTHONManager::_expireStaleWfb()
{
    if (_lastWfbUpdateMs == 0 || QDateTime::currentMSecsSinceEpoch() - _lastWfbUpdateMs <= 5000) {
        return;
    }
    const bool wasAvailable = wfbAvailable();
    _rssiAvailable = false;
    _snrAvailable = false;
    _packetLossAvailable = false;
    _bitrateAvailable = false;
    _lastWfbUpdateMs = 0;
    if (wasAvailable) {
        emit wfbAvailabilityChanged();
    }
    _updateWfbState();
}

// ---------------------------------------------------------------------------
// Generic change-notify helper
// ---------------------------------------------------------------------------

template<typename T>
bool AeroTHONManager::_setAndNotify(T &field, T value,
                                     void (AeroTHONManager::*signal)())
{
    if (field == value) {
        return false;
    }
    field = value;
    emit(this->*signal)();
    return true;
}

// Explicit instantiations for types used above
template bool AeroTHONManager::_setAndNotify(float   &, float,   void (AeroTHONManager::*)());
template bool AeroTHONManager::_setAndNotify(int     &, int,     void (AeroTHONManager::*)());
template bool AeroTHONManager::_setAndNotify(quint64 &, quint64, void (AeroTHONManager::*)());
template bool AeroTHONManager::_setAndNotify(QString &, QString, void (AeroTHONManager::*)());
template bool AeroTHONManager::_setAndNotify(AxonState &, AxonState, void (AeroTHONManager::*)());
template bool AeroTHONManager::_setAndNotify(WFBState  &, WFBState,  void (AeroTHONManager::*)());


QString AeroTHONManager::getAppDirPath() const {
    return QCoreApplication::applicationDirPath();
}
