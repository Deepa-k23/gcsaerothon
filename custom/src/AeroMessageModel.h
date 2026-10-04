#pragma once
#include <QtCore/QAbstractListModel>
#include <QtCore/QDateTime>
#include <QtCore/QTimer>
#include <QtQml/QQmlEngine>

struct AeroTextMessage {
    QString id;
    int sysId;
    int compId;
    int severity;
    QString text;
    QString description;
    QDateTime timestamp;
};

class AeroMessageModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        SysIdRole,
        CompIdRole,
        SeverityRole,
        TextRole,
        DescriptionRole,
        TimestampRole
    };

    static AeroMessageModel* instance();
    AeroMessageModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    void clear();

private slots:
    void flushPending();
    void onTextMessageReceived(int sysid, int componentid, int severity, QString text, QString description);
    void activeVehicleChanged();

private:
    QList<AeroTextMessage> m_messages;
    QList<AeroTextMessage> m_pending;
    QTimer m_batchTimer;
};
