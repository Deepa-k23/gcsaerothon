#pragma once

#include <QtCore/QFile>
#include <QtCore/QAbstractItemModel>
#include <QtCore/QJsonArray>
#include <QtCore/QJsonObject>
#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtQml/QQmlEngine>

class QJSEngine;

/// Additive AeroTHON operator/session journal. This deliberately does not
/// replace or alter QGC telemetry, MAVLink, or ULog recording.
class AeroSessionRecorder : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString sessionId READ sessionId CONSTANT)
    Q_PROPERTY(QString journalPath READ journalPath CONSTANT)
    Q_PROPERTY(QString lastReportPath READ lastReportPath NOTIFY reportGenerated)

public:
    explicit AeroSessionRecorder(QObject *parent = nullptr);
    static AeroSessionRecorder *instance();
    static AeroSessionRecorder *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    QString sessionId() const { return _sessionId; }
    QString journalPath() const { return _journal.fileName(); }
    QString lastReportPath() const { return _lastReportPath; }

    Q_INVOKABLE QString addBookmark(const QString &note = {});
    Q_INVOKABLE QString generateMissionSummary();
    Q_INVOKABLE QVariantList sessionHistory() const;
    Q_INVOKABLE QVariantList replayEvents(const QString &path) const;
    Q_INVOKABLE QVariantList preflightHistory() const;
    Q_INVOKABLE QVariantList routeQualityHistory(const QString &path) const;
    void recordMissionGraphTransition(const QString &nodeId, const QString &state);

signals:
    void eventRecorded(const QString &type);
    void reportGenerated(const QString &path);

private:
    void append(const QString &type, const QJsonObject &payload = {});
    QJsonObject modelRow(const QAbstractItemModel *model, int row) const;
    QJsonArray eventsOfType(const QString &type) const;
    QString sessionsDirectory() const;

    QString _sessionId;
    QString _lastReportPath;
    qint64 _startedAtMs{0};
    QFile _journal;
    bool _journalAvailable{false};
    QJsonArray _events;
    QHash<QString, qint64> _nodeStartedAtMs;
    qint64 _previousNodeCompletedAtMs{0};
};
