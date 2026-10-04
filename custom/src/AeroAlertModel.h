#pragma once
#include <QtCore/QAbstractListModel>
#include <QtQml/QQmlEngine>
#include <QtCore/QDateTime>
#include <QtCore/QPointer>


class QJSEngine;
class Vehicle;

enum class AlertPriority { Info=0, System=1, Mission=2, Warning=3, Critical=4 };

struct AeroAlert {
    QString id;
    AlertPriority priority{AlertPriority::Info};
    QString source;
    QString message;
    QString detail;
    QDateTime timestamp;
    bool latched{false};
    bool active{true};
    bool acknowledged{false};
    qint64 resolvedAtMs{0};
    int occurrences{1};
};

class AeroAlertModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY unreadCountChanged)
    Q_PROPERTY(bool hasCritical READ hasCritical NOTIFY hasCriticalChanged)
    Q_PROPERTY(int activeCount READ activeCount NOTIFY activeCountChanged)
public:
    enum AlertRole {
        IdRole=Qt::UserRole+1, PriorityRole, SourceRole,
        MessageRole, DetailRole, TimestampRole, LatchedRole, ActiveRole,
        AcknowledgedRole, ResolvedAtRole, OccurrencesRole, DedupeKeyRole
    };
    Q_ENUM(AlertRole)
    explicit AeroAlertModel(QObject *parent=nullptr);
    static AeroAlertModel *instance();
    static AeroAlertModel *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);
    int rowCount(const QModelIndex &p={}) const override;
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int,QByteArray> roleNames() const override;
    int unreadCount() const;
    bool hasCritical() const;
    int activeCount() const;
    Q_INVOKABLE void addAlert(const QString &priority, const QString &source, const QString &message, const QString &detail="", bool latch=false);
    Q_INVOKABLE QString raiseAlert(const QString &dedupeKey, const QString &priority, const QString &source,
                                   const QString &message, const QString &detail="", bool latch=false);
    Q_INVOKABLE void resolveAlert(const QString &dedupeKey);
    Q_INVOKABLE void acknowledge(const QString &id);
    Q_INVOKABLE void acknowledgeAll();
    Q_INVOKABLE void dismiss(const QString &id) { acknowledge(id); }
    Q_INVOKABLE void dismissAll() { acknowledgeAll(); }
    Q_INVOKABLE void clearOlderThan(int seconds);
    Q_INVOKABLE void clearMessages();
    int suppressionMs{5000};
signals:
    void unreadCountChanged();
    void hasCriticalChanged();
    void activeCountChanged();
    void newAlert(const QString &priority, const QString &source, const QString &message);
private:
    QList<AeroAlert> m_alerts;
    QHash<QString, QString> m_keysById;
    QPointer<Vehicle> _activeVehicle;
    AlertPriority priorityFromString(const QString &s) const;
    QString priorityToString(AlertPriority p) const;
    qint64 currentMs() const;
};
