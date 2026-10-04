#include "AeroDetectionEventModel.h"

#include "AeroAlertModel.h"
#include "AeroTHONManager.h"

#include <QtCore/QGlobalStatic>
#include <QtCore/QtMath>

Q_GLOBAL_STATIC(AeroDetectionEventModel, s_detectionEventModel)

AeroDetectionEventModel *AeroDetectionEventModel::instance() { return s_detectionEventModel(); }
AeroDetectionEventModel *AeroDetectionEventModel::create(QQmlEngine *, QJSEngine *) { return instance(); }

AeroDetectionEventModel::AeroDetectionEventModel(QObject *parent)
    : QAbstractListModel(parent)
{
    AeroTHONManager *manager = AeroTHONManager::instance();
    connect(manager, &AeroTHONManager::missionStateChanged, this, &AeroDetectionEventModel::updateMissionClock);
    connect(manager, &AeroTHONManager::detectionReceived, this, &AeroDetectionEventModel::recordDetection);
    connect(manager, &AeroTHONManager::qrResultReceived, this, &AeroDetectionEventModel::recordQrResult);
}

int AeroDetectionEventModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : _events.size();
}

QHash<int, QByteArray> AeroDetectionEventModel::roleNames() const
{
    return {{EventIdRole, "eventId"}, {TimestampRole, "timestamp"}, {MissionTimeRole, "missionTime"},
            {SourceTimeUsecRole, "sourceTimeUsec"}, {EventTypeRole, "eventType"},
            {MissionNodeIdRole, "missionNodeId"}, {MissionNodeLabelRole, "missionNodeLabel"},
            {SourceRole, "source"}, {ConfidenceRole, "confidence"}, {HasConfidenceRole, "hasConfidence"},
            {QrPayloadRole, "qrPayload"}, {QrValidRole, "qrValid"}, {QrDuplicateRole, "qrDuplicate"},
            {HasPositionRole, "hasPosition"}, {LatitudeRole, "latitude"}, {LongitudeRole, "longitude"},
            {AltitudeRole, "altitude"}, {SnapshotReferenceRole, "snapshotReference"}, {MetadataRole, "metadata"}};
}

QVariant AeroDetectionEventModel::data(const QModelIndex &modelIndex, int role) const
{
    if (!modelIndex.isValid() || modelIndex.row() < 0 || modelIndex.row() >= _events.size()) return {};
    const AeroDetectionEvent &event = _events.at(modelIndex.row());
    switch (static_cast<Role>(role)) {
    case EventIdRole: return event.eventId;
    case TimestampRole: return event.timestampMs;
    case MissionTimeRole: return event.missionTimeMs;
    case SourceTimeUsecRole: return QVariant::fromValue(event.sourceTimeUsec);
    case EventTypeRole: return event.eventType;
    case MissionNodeIdRole: return event.missionNodeId;
    case MissionNodeLabelRole: return event.missionNodeLabel;
    case SourceRole: return event.source;
    case ConfidenceRole: return event.confidence;
    case HasConfidenceRole: return event.hasConfidence;
    case QrPayloadRole: return event.qrPayload;
    case QrValidRole: return event.qrValid;
    case QrDuplicateRole: return event.qrDuplicate;
    case HasPositionRole: return event.hasPosition;
    case LatitudeRole: return event.hasPosition ? QVariant(event.latitude) : QVariant();
    case LongitudeRole: return event.hasPosition ? QVariant(event.longitude) : QVariant();
    case AltitudeRole: return event.hasPosition ? QVariant(event.altitude) : QVariant();
    case SnapshotReferenceRole: return event.snapshotReference;
    case MetadataRole: return event.metadata;
    }
    return {};
}

QVariantMap AeroDetectionEventModel::toMap(const AeroDetectionEvent &event) const
{
    QVariantMap result;
    const auto roles = roleNames();
    const int row = static_cast<int>(&event - _events.constData());
    for (auto it = roles.cbegin(); it != roles.cend(); ++it) {
        result.insert(QString::fromLatin1(it.value()), data(index(row), it.key()));
    }
    return result;
}

QVariantMap AeroDetectionEventModel::eventAt(int row) const
{
    return row >= 0 && row < _events.size() ? toMap(_events.at(row)) : QVariantMap{};
}

QVariantList AeroDetectionEventModel::positionedEvents() const
{
    QVariantList result;
    for (const AeroDetectionEvent &event : _events) {
        if (event.hasPosition) result.append(toMap(event));
    }
    return result;
}

void AeroDetectionEventModel::recordDetection(quint32 detectionId, int detectionType, int cameraId,
                                               float confidence, float distance, quint64 sourceTimeUsec)
{
    const QString id = QStringLiteral("detection:%1").arg(detectionId);
    if (findEvent(id) >= 0) return;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const QString missionState = AeroTHONManager::instance()->missionState();
    AeroDetectionEvent event;
    event.eventId = id;
    event.timestampMs = now;
    event.missionTimeMs = _missionStartMs >= 0 ? now - _missionStartMs : -1;
    event.sourceTimeUsec = sourceTimeUsec;
    event.eventType = detectionTypeName(detectionType);
    event.missionNodeId = missionNodeId(missionState);
    event.missionNodeLabel = missionNodeLabel(missionState);
    event.source = cameraName(cameraId);
    event.confidence = confidence;
    event.hasConfidence = qIsFinite(confidence) && confidence >= 0.F && confidence <= 1.F;
    event.metadata.insert(QStringLiteral("detectionTypeId"), detectionType);
    event.metadata.insert(QStringLiteral("cameraId"), cameraId);
    event.metadata.insert(QStringLiteral("distanceM"), qIsFinite(distance) ? QVariant(distance) : QVariant());
    event.metadata.insert(QStringLiteral("positionAvailable"), false);
    beginInsertRows({}, 0, 0);
    _events.prepend(event);
    endInsertRows();
    emit countChanged();
    emit eventRecorded(id, event.missionNodeId);
    AeroAlertModel::instance()->raiseAlert(id, QStringLiteral("MISSION"), event.source,
                                           QStringLiteral("%1 detected").arg(event.eventType),
                                           event.missionNodeLabel.isEmpty() ? QStringLiteral("No active mission task")
                                                                            : QStringLiteral("Task: %1").arg(event.missionNodeLabel));
}

void AeroDetectionEventModel::recordQrResult(quint32 detectionId, const QString &payload, bool valid, bool duplicate,
                                              int cameraId, quint64 sourceTimeUsec)
{
    const QString id = QStringLiteral("detection:%1").arg(detectionId);
    int row = findEvent(id);
    if (row < 0) {
        recordDetection(detectionId, 1, cameraId, qQNaN(), qQNaN(), sourceTimeUsec);
        row = findEvent(id);
    }
    if (row < 0) return;
    AeroDetectionEvent &event = _events[row];
    event.eventType = QStringLiteral("QR");
    event.qrPayload = payload;
    event.qrValid = valid;
    event.qrDuplicate = duplicate;
    event.metadata.insert(QStringLiteral("qrValidity"), valid ? QStringLiteral("VALID") : QStringLiteral("INVALID"));
    emit dataChanged(index(row), index(row), {EventTypeRole, QrPayloadRole, QrValidRole, QrDuplicateRole, MetadataRole});
    emit eventUpdated(id);
}

bool AeroDetectionEventModel::associatePosition(const QString &eventId, double latitude, double longitude, double altitude)
{
    if (!qIsFinite(latitude) || !qIsFinite(longitude) || latitude < -90. || latitude > 90. || longitude < -180. || longitude > 180.) return false;
    const int row = findEvent(eventId);
    if (row < 0) return false;
    AeroDetectionEvent &event = _events[row];
    event.hasPosition = true; event.latitude = latitude; event.longitude = longitude; event.altitude = altitude;
    event.metadata.insert(QStringLiteral("positionAvailable"), true);
    emit dataChanged(index(row), index(row), {HasPositionRole, LatitudeRole, LongitudeRole, AltitudeRole, MetadataRole});
    emit eventUpdated(eventId);
    emit positionedEventsChanged();
    return true;
}

bool AeroDetectionEventModel::attachSnapshot(const QString &eventId, const QString &snapshotReference)
{
    if (snapshotReference.trimmed().isEmpty()) return false;
    const int row = findEvent(eventId);
    if (row < 0) return false;
    _events[row].snapshotReference = snapshotReference;
    emit dataChanged(index(row), index(row), {SnapshotReferenceRole});
    emit eventUpdated(eventId);
    return true;
}

void AeroDetectionEventModel::clearSession()
{
    beginResetModel(); _events.clear(); endResetModel();
    _missionStartMs = -1;
    emit countChanged();
    emit positionedEventsChanged();
}

int AeroDetectionEventModel::findEvent(const QString &eventId) const
{
    for (int i = 0; i < _events.size(); ++i) if (_events.at(i).eventId == eventId) return i;
    return -1;
}

void AeroDetectionEventModel::updateMissionClock()
{
    const QString state = AeroTHONManager::instance()->missionState();
    if (state == QStringLiteral("IDLE")) { clearSession(); return; }
    if (_missionStartMs < 0 && state != QStringLiteral("UNKNOWN")) _missionStartMs = QDateTime::currentMSecsSinceEpoch();
}

QString AeroDetectionEventModel::detectionTypeName(int type)
{
    static const QStringList names = {QStringLiteral("UNKNOWN"), QStringLiteral("QR"), QStringLiteral("RED ZONE"),
                                      QStringLiteral("GREEN BANNER"), QStringLiteral("DELIVERY ZONE"), QStringLiteral("OBSTACLE")};
    return type >= 0 && type < names.size() ? names.at(type) : QStringLiteral("UNKNOWN");
}

QString AeroDetectionEventModel::cameraName(int cameraId)
{
    if (cameraId == 0) return QStringLiteral("FPV");
    if (cameraId == 1) return QStringLiteral("NADIR");
    return QStringLiteral("CAMERA");
}

QString AeroDetectionEventModel::missionNodeId(const QString &state)
{
    if (state == QStringLiteral("PREFLIGHT")) return QStringLiteral("n0");
    if (state == QStringLiteral("TAKEOFF")) return QStringLiteral("n2");
    if (state == QStringLiteral("INITIAL QR")) return QStringLiteral("n3");
    if (state == QStringLiteral("AREA SEARCH")) return QStringLiteral("n4");
    if (state == QStringLiteral("BANNER SEARCH")) return QStringLiteral("n5");
    if (state == QStringLiteral("CORRIDOR ENTRY") || state == QStringLiteral("CORRIDOR FLIGHT")) return QStringLiteral("n6");
    if (state == QStringLiteral("DELIVERY SEARCH") || state == QStringLiteral("PAYLOAD DELIVERY")) return QStringLiteral("n7");
    if (state == QStringLiteral("RETURN CORRIDOR") || state == QStringLiteral("RTL")) return QStringLiteral("n8");
    if (state == QStringLiteral("LANDING")) return QStringLiteral("n9");
    return {};
}

QString AeroDetectionEventModel::missionNodeLabel(const QString &state)
{
    return missionNodeId(state).isEmpty() ? QString{} : state;
}
