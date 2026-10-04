#include "AeroSessionRecorder.h"

#include "AeroAlertModel.h"
#include "AeroDetectionEventModel.h"
#include "AeroTHONManager.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QJsonDocument>
#include <QtCore/QSaveFile>
#include <QtCore/QStandardPaths>
#include <QtCore/QUuid>
#include <QtPositioning/QGeoCoordinate>

Q_GLOBAL_STATIC(AeroSessionRecorder, s_sessionRecorder)

AeroSessionRecorder *AeroSessionRecorder::instance() { return s_sessionRecorder(); }
AeroSessionRecorder *AeroSessionRecorder::create(QQmlEngine *, QJSEngine *) { return instance(); }

AeroSessionRecorder::AeroSessionRecorder(QObject *parent)
    : QObject(parent)
    , _sessionId(QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd-HHmmss")) + QLatin1Char('-')
                 + QUuid::createUuid().toString(QUuid::WithoutBraces).left(8))
    , _startedAtMs(QDateTime::currentMSecsSinceEpoch())
{
    const QString directory = sessionsDirectory();
    QDir().mkpath(directory);
    _journal.setFileName(directory + QLatin1Char('/') + _sessionId + QStringLiteral(".jsonl"));
    _journalAvailable = _journal.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text);
    append(QStringLiteral("session_started"), {{QStringLiteral("schemaVersion"), 1}});

    AeroTHONManager *manager = AeroTHONManager::instance();
    connect(manager, &AeroTHONManager::missionStateChanged, this, [this, manager]() {
        append(QStringLiteral("mission_state"), {{QStringLiteral("state"), manager->missionState()},
                                                  {QStringLiteral("progress"), manager->missionProgress()},
                                                  {QStringLiteral("waypointProgress"), manager->routeProgress()},
                                                  {QStringLiteral("checksum"), static_cast<qint64>(manager->missionChecksum())}});
    });
    connect(manager, &AeroTHONManager::commandAckReceived, this,
            [this](quint32 requestId, int command, int result, int progress, int reason, const QString &message) {
        append(QStringLiteral("command_ack"), {{QStringLiteral("requestId"), static_cast<qint64>(requestId)},
                                                {QStringLiteral("command"), command}, {QStringLiteral("result"), result},
                                                {QStringLiteral("progress"), progress}, {QStringLiteral("reason"), reason},
                                                {QStringLiteral("message"), message}});
    });
    connect(manager, &AeroTHONManager::displayUpdateReady, this, [this, manager]() {
        QJsonObject payload{{QStringLiteral("axonState"), static_cast<int>(manager->axonState())},
                            {QStringLiteral("cpuPct"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->cpuPct())},
                            {QStringLiteral("ramPct"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->ramPct())},
                            {QStringLiteral("temperatureC"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->tempC())},
                            {QStringLiteral("fpvFps"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->fpvFps())},
                            {QStringLiteral("nadirFps"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->nadirFps())},
                            {QStringLiteral("wfbLossPct"), manager->packetLossAvailable() ? QJsonValue(manager->packetLossPct()) : QJsonValue{}},
                            {QStringLiteral("wfbRssiDbm"), manager->rssiAvailable() ? QJsonValue(manager->rssiDbm()) : QJsonValue{}},
                            {QStringLiteral("wfbSnrDb"), manager->snrAvailable() ? QJsonValue(manager->snrDb()) : QJsonValue{}},
                            {QStringLiteral("wfbBitrateMbps"), manager->bitrateAvailable() ? QJsonValue(manager->bitrateMbps()) : QJsonValue{}}};
        Vehicle *vehicle = MultiVehicleManager::instance()->activeVehicle();
        if (vehicle) {
            const QGeoCoordinate coordinate = vehicle->coordinate();
            if (coordinate.isValid()) {
                payload[QStringLiteral("latitude")] = coordinate.latitude();
                payload[QStringLiteral("longitude")] = coordinate.longitude();
                payload[QStringLiteral("altitude")] = coordinate.altitude();
            }
        }
        append(QStringLiteral("health_sample"), payload);
    });

    AeroDetectionEventModel *detections = AeroDetectionEventModel::instance();
    connect(detections, &QAbstractItemModel::rowsInserted, this,
            [this, detections](const QModelIndex &, int first, int last) {
        for (int row = first; row <= last; ++row) append(QStringLiteral("detection"), QJsonObject::fromVariantMap(detections->eventAt(row)));
    });
    AeroAlertModel *alerts = AeroAlertModel::instance();
    connect(alerts, &QAbstractItemModel::rowsInserted, this, [this, alerts](const QModelIndex &, int first, int last) {
        for (int row = first; row <= last; ++row) append(QStringLiteral("alert"), modelRow(alerts, row));
    });
    
}

QString AeroSessionRecorder::sessionsDirectory() const
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/AeroTHON/sessions");
}

void AeroSessionRecorder::append(const QString &type, const QJsonObject &payload)
{
    QJsonObject event{{QStringLiteral("timestampMs"), QDateTime::currentMSecsSinceEpoch()},
                      {QStringLiteral("missionTimeMs"), QDateTime::currentMSecsSinceEpoch() - _startedAtMs},
                      {QStringLiteral("type"), type}, {QStringLiteral("data"), payload}};
    _events.append(event);
    if (_journalAvailable && _journal.isOpen()) {
        _journal.write(QJsonDocument(event).toJson(QJsonDocument::Compact));
        _journal.write("\n");
        _journal.flush();
    }
    emit eventRecorded(type);
}

QJsonObject AeroSessionRecorder::modelRow(const QAbstractItemModel *model, int row) const
{
    QJsonObject object;
    const QModelIndex index = model->index(row, 0);
    // roleNames() returns by value. Keep that value alive for the full iteration;
    // taking begin/end from separate temporaries leaves both iterators dangling.
    const QHash<int, QByteArray> roles = model->roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        object[QString::fromUtf8(it.value())] = QJsonValue::fromVariant(model->data(index, it.key()));
    return object;
}

void AeroSessionRecorder::recordMissionGraphTransition(const QString &nodeId, const QString &state)
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QJsonObject payload{{QStringLiteral("nodeId"), nodeId}, {QStringLiteral("state"), state},
                        {QStringLiteral("stageDurationMs"), QJsonValue{}}, {QStringLiteral("executionDurationMs"), QJsonValue{}}};
    if (state == QStringLiteral("ACTIVE")) {
        _nodeStartedAtMs[nodeId] = now;
    } else if (state == QStringLiteral("COMPLETED")) {
        if (_nodeStartedAtMs.contains(nodeId)) payload[QStringLiteral("executionDurationMs")] = now - _nodeStartedAtMs.value(nodeId);
        if (_previousNodeCompletedAtMs > 0) payload[QStringLiteral("stageDurationMs")] = now - _previousNodeCompletedAtMs;
        _previousNodeCompletedAtMs = now;
    }
    append(QStringLiteral("mission_graph_transition"), payload);
}

QString AeroSessionRecorder::addBookmark(const QString &note)
{
    QJsonObject payload{{QStringLiteral("note"), note}};
    Vehicle *vehicle = MultiVehicleManager::instance()->activeVehicle();
    if (vehicle && vehicle->coordinate().isValid()) {
        payload[QStringLiteral("latitude")] = vehicle->coordinate().latitude();
        payload[QStringLiteral("longitude")] = vehicle->coordinate().longitude();
        payload[QStringLiteral("altitude")] = vehicle->coordinate().altitude();
    }
    payload[QStringLiteral("missionState")] = AeroTHONManager::instance()->missionState();
    append(QStringLiteral("bookmark"), payload);
    return _sessionId;
}

QJsonArray AeroSessionRecorder::eventsOfType(const QString &type) const
{
    QJsonArray result;
    for (const QJsonValue &value : _events)
        if (value.toObject().value(QStringLiteral("type")).toString() == type) result.append(value);
    return result;
}

QString AeroSessionRecorder::generateMissionSummary()
{
    const qint64 endMs = QDateTime::currentMSecsSinceEpoch();
    AeroTHONManager *manager = AeroTHONManager::instance();
    QJsonArray qrEvents;
    QJsonArray bannerEvents;
    for (const QJsonValue &value : eventsOfType(QStringLiteral("detection"))) {
        const QString eventType = value.toObject().value(QStringLiteral("data")).toObject().value(QStringLiteral("eventType")).toString();
        if (eventType == QStringLiteral("QR")) qrEvents.append(value);
        if (eventType == QStringLiteral("BANNER")) bannerEvents.append(value);
    }
    double lossSum = 0.;
    double lossMin = 101.;
    double lossMax = -1.;
    int lossCount = 0;
    QJsonArray routeQuality;
    const QJsonArray health = eventsOfType(QStringLiteral("health_sample"));
    for (const QJsonValue &value : health) {
        const QJsonObject data = value.toObject().value(QStringLiteral("data")).toObject();
        if (!data.value(QStringLiteral("wfbLossPct")).isNull() && data.value(QStringLiteral("wfbLossPct")).isDouble()) {
            const double loss = data.value(QStringLiteral("wfbLossPct")).toDouble();
            lossSum += loss;
            lossMin = qMin(lossMin, loss);
            lossMax = qMax(lossMax, loss);
            ++lossCount;
            if (data.contains(QStringLiteral("latitude")) && data.contains(QStringLiteral("longitude"))) routeQuality.append(value);
        }
    }
    const QJsonObject wfbSummary{{QStringLiteral("samples"), lossCount},
                                 {QStringLiteral("packetLossAvgPct"), lossCount ? QJsonValue(lossSum / lossCount) : QJsonValue{}},
                                 {QStringLiteral("packetLossMinPct"), lossCount ? QJsonValue(lossMin) : QJsonValue{}},
                                 {QStringLiteral("packetLossMaxPct"), lossCount ? QJsonValue(lossMax) : QJsonValue{}},
                                 {QStringLiteral("routeQualitySamples"), routeQuality}};
    QJsonObject summary{{QStringLiteral("schemaVersion"), 1}, {QStringLiteral("sessionId"), _sessionId},
                        {QStringLiteral("missionIdentity"), QJsonObject{{QStringLiteral("checksum"), static_cast<qint64>(manager->missionChecksum())},
                                                                         {QStringLiteral("activeTarget"), manager->activeTarget()}}},
                        {QStringLiteral("startMs"), _startedAtMs}, {QStringLiteral("endMs"), endMs},
                        {QStringLiteral("durationMs"), endMs - _startedAtMs},
                        {QStringLiteral("missionStates"), eventsOfType(QStringLiteral("mission_state"))},
                        {QStringLiteral("missionStageTransitions"), eventsOfType(QStringLiteral("mission_graph_transition"))},
                        {QStringLiteral("waypointProgress"), manager->routeProgress()},
                        {QStringLiteral("detections"), eventsOfType(QStringLiteral("detection"))},
                        {QStringLiteral("qrEvents"), qrEvents}, {QStringLiteral("bannerEvents"), bannerEvents},
                        {QStringLiteral("alerts"), eventsOfType(QStringLiteral("alert"))},
                        {QStringLiteral("preflight"), eventsOfType(QStringLiteral("preflight"))},
                        {QStringLiteral("commandAcknowledgements"), eventsOfType(QStringLiteral("command_ack"))},
                        {QStringLiteral("healthTimeline"), health},
                        {QStringLiteral("cameraHealthSummary"), QJsonObject{{QStringLiteral("fpvFps"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->fpvFps())},
                                                                             {QStringLiteral("nadirFps"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->nadirFps())}}},
                        {QStringLiteral("axonHealthSummary"), QJsonObject{{QStringLiteral("state"), static_cast<int>(manager->axonState())},
                                                                           {QStringLiteral("cpuPct"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->cpuPct())},
                                                                           {QStringLiteral("ramPct"), manager->axonState() == AeroTHONManager::AxonState::Unknown ? QJsonValue{} : QJsonValue(manager->ramPct())}}},
                        {QStringLiteral("wfbStatistics"), wfbSummary},
                        {QStringLiteral("bookmarks"), eventsOfType(QStringLiteral("bookmark"))}};
    _lastReportPath = QFileInfo(_journal).absolutePath() + QLatin1Char('/') + _sessionId + QStringLiteral("-summary.json");
    QSaveFile output(_lastReportPath);
    if (!output.open(QIODevice::WriteOnly) || output.write(QJsonDocument(summary).toJson(QJsonDocument::Indented)) < 0 || !output.commit())
        return {};
    emit reportGenerated(_lastReportPath);
    return _lastReportPath;
}

QVariantList AeroSessionRecorder::sessionHistory() const
{
    QVariantList result;
    const QFileInfoList files = QDir(sessionsDirectory()).entryInfoList({QStringLiteral("*.jsonl")}, QDir::Files, QDir::Time);
    for (const QFileInfo &file : files)
        result.append(QVariantMap{{QStringLiteral("sessionId"), file.completeBaseName()},
                                  {QStringLiteral("path"), file.absoluteFilePath()},
                                  {QStringLiteral("startedAtMs"), file.birthTime().toMSecsSinceEpoch()},
                                  {QStringLiteral("sizeBytes"), file.size()}});
    return result;
}

QVariantList AeroSessionRecorder::replayEvents(const QString &path) const
{
    QVariantList result;
    const QFileInfo requested(path);
    if (requested.suffix() != QStringLiteral("jsonl") || requested.absolutePath() != QFileInfo(sessionsDirectory()).absoluteFilePath()) return result;
    QFile input(requested.absoluteFilePath());
    if (!input.open(QIODevice::ReadOnly | QIODevice::Text)) return result;
    while (!input.atEnd()) {
        const QJsonDocument document = QJsonDocument::fromJson(input.readLine());
        if (document.isObject()) result.append(document.object().toVariantMap());
    }
    return result;
}

QVariantList AeroSessionRecorder::preflightHistory() const
{
    QVariantList result;
    for (const QVariant &session : sessionHistory()) {
        const QVariantMap descriptor = session.toMap();
        for (const QVariant &event : replayEvents(descriptor.value(QStringLiteral("path")).toString())) {
            const QVariantMap object = event.toMap();
            if (object.value(QStringLiteral("type")).toString() == QStringLiteral("preflight")) {
                QVariantMap entry = object.value(QStringLiteral("data")).toMap();
                entry[QStringLiteral("timestampMs")] = object.value(QStringLiteral("timestampMs"));
                entry[QStringLiteral("sessionId")] = descriptor.value(QStringLiteral("sessionId"));
                result.append(entry);
            }
        }
    }
    return result;
}

QVariantList AeroSessionRecorder::routeQualityHistory(const QString &path) const
{
    QVariantList result;
    for (const QVariant &event : replayEvents(path)) {
        const QVariantMap object = event.toMap();
        if (object.value(QStringLiteral("type")).toString() != QStringLiteral("health_sample")) continue;
        QVariantMap data = object.value(QStringLiteral("data")).toMap();
        if (!data.contains(QStringLiteral("latitude")) || !data.contains(QStringLiteral("longitude"))
            || data.value(QStringLiteral("wfbLossPct")).isNull()) continue;
        data[QStringLiteral("timestampMs")] = object.value(QStringLiteral("timestampMs"));
        result.append(data);
    }
    return result;
}
