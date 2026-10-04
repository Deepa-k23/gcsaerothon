#include "AeroMessageModel.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"
#include <QtCore/QUuid>
#include <QDebug>

Q_GLOBAL_STATIC(AeroMessageModel, s_aeroMessageModel)

AeroMessageModel* AeroMessageModel::instance() {
    return s_aeroMessageModel();
}

AeroMessageModel::AeroMessageModel(QObject *parent) : QAbstractListModel(parent) {
    m_batchTimer.setInterval(250);
    connect(&m_batchTimer, &QTimer::timeout, this, &AeroMessageModel::flushPending);
    m_batchTimer.start();

    connect(MultiVehicleManager::instance(), &MultiVehicleManager::activeVehicleChanged, this, &AeroMessageModel::activeVehicleChanged);
    activeVehicleChanged();
}

void AeroMessageModel::activeVehicleChanged() {
    Vehicle* activeVehicle = MultiVehicleManager::instance()->activeVehicle();
    if (activeVehicle) {
        connect(activeVehicle, &Vehicle::textMessageReceived, this, &AeroMessageModel::onTextMessageReceived, Qt::UniqueConnection);
    }
}

void AeroMessageModel::onTextMessageReceived(int sysid, int componentid, int severity, QString text, QString description) {
    AeroTextMessage msg;
    msg.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    msg.sysId = sysid;
    msg.compId = componentid;
    msg.severity = severity;
    msg.text = text;
    msg.description = description;
    msg.timestamp = QDateTime::currentDateTimeUtc();
    
    m_pending.append(msg);
    if (m_pending.size() > 1000) {
        m_pending.removeFirst();
    }
}

void AeroMessageModel::flushPending() {
    if (m_pending.isEmpty()) return;
    
    const int maxItems = 1000;
    
    beginInsertRows({}, 0, m_pending.size() - 1);
    for (int i = 0; i < m_pending.size(); ++i) {
        m_messages.prepend(m_pending[i]);
    }
    m_pending.clear();
    endInsertRows();
    
    if (m_messages.size() > maxItems) {
        int over = m_messages.size() - maxItems;
        beginRemoveRows({}, m_messages.size() - over, m_messages.size() - 1);
        m_messages.remove(m_messages.size() - over, over);
        endRemoveRows();
    }
}

int AeroMessageModel::rowCount(const QModelIndex &parent) const {
    if (parent.isValid()) return 0;
    return m_messages.size();
}

QVariant AeroMessageModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() >= m_messages.size()) return QVariant();
    
    const AeroTextMessage &msg = m_messages.at(index.row());
    switch (role) {
    case IdRole: return msg.id;
    case SysIdRole: return msg.sysId;
    case CompIdRole: return msg.compId;
    case SeverityRole: return msg.severity;
    case TextRole: return msg.text;
    case DescriptionRole: return msg.description;
    case TimestampRole: return msg.timestamp;
    default: return QVariant();
    }
}

QHash<int, QByteArray> AeroMessageModel::roleNames() const {
    QHash<int, QByteArray> roles;
    roles[IdRole] = "id";
    roles[SysIdRole] = "sysId";
    roles[CompIdRole] = "compId";
    roles[SeverityRole] = "severity";
    roles[TextRole] = "text";
    roles[DescriptionRole] = "description";
    roles[TimestampRole] = "timestamp";
    return roles;
}

void AeroMessageModel::clear() {
    beginResetModel();
    m_messages.clear();
    m_pending.clear();
    endResetModel();
}
