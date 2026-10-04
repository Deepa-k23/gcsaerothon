#pragma once

#include <QtCore/QAbstractListModel>
#include <QtCore/QDateTime>
#include <QtCore/QVariantMap>
#include <QtQml/QQmlEngine>

class QJSEngine;

struct AeroDetectionEvent
{
    QString eventId;
    qint64 timestampMs{0};
    qint64 missionTimeMs{-1};
    quint64 sourceTimeUsec{0};
    QString eventType;
    QString missionNodeId;
    QString missionNodeLabel;
    QString source;
    float confidence{0.F};
    bool hasConfidence{false};
    QString qrPayload;
    bool qrValid{false};
    bool qrDuplicate{false};
    bool hasPosition{false};
    double latitude{0.};
    double longitude{0.};
    double altitude{0.};
    QString snapshotReference;
    QVariantMap metadata;
};

/// Session-scoped, source-of-truth store for AeroTHON perception events.
/// Geographic data is absent until explicitly supplied by a correlated source.
class AeroDetectionEventModel : public QAbstractListModel
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(QVariantList positionedEvents READ positionedEvents NOTIFY positionedEventsChanged)

public:
    enum Role {
        EventIdRole = Qt::UserRole + 1,
        TimestampRole,
        MissionTimeRole,
        SourceTimeUsecRole,
        EventTypeRole,
        MissionNodeIdRole,
        MissionNodeLabelRole,
        SourceRole,
        ConfidenceRole,
        HasConfidenceRole,
        QrPayloadRole,
        QrValidRole,
        QrDuplicateRole,
        HasPositionRole,
        LatitudeRole,
        LongitudeRole,
        AltitudeRole,
        SnapshotReferenceRole,
        MetadataRole,
    };
    Q_ENUM(Role)

    static AeroDetectionEventModel *instance();
    static AeroDetectionEventModel *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QVariantMap eventAt(int row) const;
    QVariantList positionedEvents() const;
    Q_INVOKABLE bool associatePosition(const QString &eventId, double latitude, double longitude, double altitude);
    Q_INVOKABLE bool attachSnapshot(const QString &eventId, const QString &snapshotReference);
    Q_INVOKABLE void clearSession();

signals:
    void countChanged();
    void eventRecorded(const QString &eventId, const QString &missionNodeId);
    void eventUpdated(const QString &eventId);
    void positionedEventsChanged();

public:
    explicit AeroDetectionEventModel(QObject *parent = nullptr);

private:
    void recordDetection(quint32 detectionId, int detectionType, int cameraId,
                         float confidence, float distance, quint64 sourceTimeUsec);
    void recordQrResult(quint32 detectionId, const QString &payload, bool valid, bool duplicate,
                        int cameraId, quint64 sourceTimeUsec);
    int findEvent(const QString &eventId) const;
    void updateMissionClock();
    static QString detectionTypeName(int detectionType);
    static QString cameraName(int cameraId);
    static QString missionNodeId(const QString &missionState);
    static QString missionNodeLabel(const QString &missionState);
    QVariantMap toMap(const AeroDetectionEvent &event) const;

    QList<AeroDetectionEvent> _events;
    qint64 _missionStartMs{-1};
};
