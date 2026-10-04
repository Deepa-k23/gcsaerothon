#include "AeroAlertModel.h"
#include "Vehicle.h"
#include "MultiVehicleManager.h"
#include "QGCApplication.h"
#include "AeroTHONManager.h"
#include "MAVLinkProtocol.h"
#include <QtCore/QUuid>

#include <QtCore/QCoreApplication>

Q_GLOBAL_STATIC(AeroAlertModel, s_aeroAlertModel)

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

AeroAlertModel::AeroAlertModel(QObject *parent)
    : QAbstractListModel(parent)
{
    AeroTHONManager *manager = AeroTHONManager::instance();
    connect(manager, &AeroTHONManager::axonStateChanged, this, [this, manager]() {
        const auto state = manager->axonState();
        if (state == AeroTHONManager::AxonState::Online) {
            resolveAlert(QStringLiteral("AXON:connectivity"));
        } else if (state == AeroTHONManager::AxonState::Degraded) {
            raiseAlert(QStringLiteral("AXON:connectivity"), QStringLiteral("WARNING"), QStringLiteral("AXON"),
                       QStringLiteral("Axon connection degraded"), QStringLiteral("Health response is stale"));
        } else if (state == AeroTHONManager::AxonState::Lost) {
            raiseAlert(QStringLiteral("AXON:connectivity"), QStringLiteral("CRITICAL"), QStringLiteral("AXON"),
                       QStringLiteral("Axon connection lost"), QStringLiteral("No recent health response"), true);
        }
    });
    connect(manager, &AeroTHONManager::commandAckReceived, this,
            [this](quint32 requestId, int command, int result, int progress, int reasonCode, const QString &message) {
        const QString key = QStringLiteral("ACK:%1").arg(requestId);
        const QString detail = QStringLiteral("Command %1, result %2, progress %3%, reason %4%5")
                                   .arg(command).arg(result).arg(progress).arg(reasonCode)
                                   .arg(message.isEmpty() ? QString{} : QStringLiteral(": ") + message);
        const bool failed = result >= 1 && result <= 4;
        raiseAlert(key, failed ? QStringLiteral("WARNING") : QStringLiteral("SYSTEM"), QStringLiteral("MISSION"),
                   failed ? QStringLiteral("Command not accepted") : QStringLiteral("Command acknowledged"), detail);
    });
    connect(manager, &AeroTHONManager::missionCompleted, this, [this]() {
        raiseAlert(QStringLiteral("MISSION:complete"), QStringLiteral("MISSION"), QStringLiteral("MISSION"),
                   QStringLiteral("Mission complete"));
    });
    connect(manager, &AeroTHONManager::wfbStateChanged, this, [this, manager]() {
        switch (manager->wfbState()) {
        case AeroTHONManager::WFBState::Normal:
            resolveAlert(QStringLiteral("WFB:packet-loss"));
            break;
        case AeroTHONManager::WFBState::Warning:
            raiseAlert(QStringLiteral("WFB:packet-loss"), QStringLiteral("WARNING"), QStringLiteral("WFB"),
                       QStringLiteral("WFB packet loss elevated"),
                       QStringLiteral("%1% packet loss").arg(manager->packetLossPct(), 0, 'f', 1));
            break;
        case AeroTHONManager::WFBState::Critical:
            raiseAlert(QStringLiteral("WFB:packet-loss"), QStringLiteral("CRITICAL"), QStringLiteral("WFB"),
                       QStringLiteral("WFB link critically degraded"),
                       QStringLiteral("%1% packet loss").arg(manager->packetLossPct(), 0, 'f', 1), true);
            break;
        case AeroTHONManager::WFBState::Unknown:
            resolveAlert(QStringLiteral("WFB:packet-loss"));
            break;
        }
    });
    connect(manager, &AeroTHONManager::wfbAvailabilityChanged, this,
            [this, manager, previouslyAvailable = false]() mutable {
        if (manager->wfbAvailable()) {
            previouslyAvailable = true;
            resolveAlert(QStringLiteral("WFB:freshness"));
        } else if (previouslyAvailable) {
            raiseAlert(QStringLiteral("WFB:freshness"), QStringLiteral("CRITICAL"), QStringLiteral("WFB"),
                       QStringLiteral("WFB telemetry lost"), QStringLiteral("No WFB sample received for 5 seconds"), true);
        }
    });
    

    // --- Vehicle armed / disarmed alerts ---
    MultiVehicleManager *mvm = MultiVehicleManager::instance();
    connect(mvm, &MultiVehicleManager::activeVehicleChanged, this, [this](Vehicle *vehicle) {
        if (_activeVehicle) {
            disconnect(_activeVehicle, nullptr, this, nullptr);
        }
        _activeVehicle = vehicle;
        if (_activeVehicle) {
            connect(_activeVehicle, &Vehicle::armedChanged, this, [this](bool armed) {
                if (armed) {
                    raiseAlert(QStringLiteral("VEHICLE:armed"), QStringLiteral("SYSTEM"), QStringLiteral("PX4"),
                               QStringLiteral("Vehicle armed"));
                } else {
                    raiseAlert(QStringLiteral("VEHICLE:disarmed"), QStringLiteral("SYSTEM"), QStringLiteral("PX4"),
                               QStringLiteral("Vehicle disarmed"));
                }
            });
            connect(_activeVehicle, &Vehicle::flightModeChanged, this, [this](const QString &flightMode) {
                raiseAlert(QStringLiteral("VEHICLE:mode"), QStringLiteral("SYSTEM"), QStringLiteral("PX4"),
                           QStringLiteral("Flight mode: %1").arg(flightMode));
            });
            connect(_activeVehicle, &Vehicle::mavlinkMessageReceived, this,
                    [this](const mavlink_message_t &message) {
                // Surface PX4 statustext / heartbeat warnings as messages.
                // MAVLink MSG_ID_STATUSTEXT = 253 (standard messages).
                if (message.msgid == 253) {
                    // Text extracted by Vehicle::mavlinkMessageReceived path; we rely on
                    // Vehicle::textMessageReceived instead to avoid re-parsing.
                }
            });
            connect(_activeVehicle, &Vehicle::textMessageReceived, this,
                    [this](int sysid, int compid, int severity, const QString &text, const QString &description) {
                // Map MAVLink severity to our priority levels.
                QString priority;
                if (severity <= 1)      priority = QStringLiteral("CRITICAL");
                else if (severity <= 3) priority = QStringLiteral("WARNING");
                else if (severity <= 4) priority = QStringLiteral("WARNING");
                else                    priority = QStringLiteral("SYSTEM");

                // Dedupe key includes system/component so different sources don't collide.
                const QString key = QStringLiteral("PX4TEXT:%1:%2:%3").arg(sysid).arg(compid).arg(text);
                raiseAlert(key, priority, QStringLiteral("PX4"), text, description);
            });
        }
    });

    // --- Mission state transition alerts ---
    


    connect(manager, &AeroTHONManager::missionStateChanged, this, [this, manager]() {
        const QString state = manager->missionState();
        if (!state.isEmpty() && state != QStringLiteral("UNKNOWN")) {
            const QString key = QStringLiteral("MISSION:state:") + state;
            raiseAlert(key, QStringLiteral("MISSION"),
                       QStringLiteral("MISSION"), QStringLiteral("Mission: %1").arg(state));
        }
    });
}

AeroAlertModel *AeroAlertModel::instance() { return s_aeroAlertModel(); }

AeroAlertModel *AeroAlertModel::create(QQmlEngine *, QJSEngine *) { return instance(); }

// ---------------------------------------------------------------------------
// QAbstractListModel interface
// ---------------------------------------------------------------------------

int AeroAlertModel::rowCount(const QModelIndex &p) const
{
    if (p.isValid()) {
        return 0;
    }
    return m_alerts.size();
}

QHash<int, QByteArray> AeroAlertModel::roleNames() const
{
    return {
        {IdRole,        "alertId"},
        {PriorityRole,  "priority"},
        {SourceRole,    "source"},
        {MessageRole,   "message"},
        {DetailRole,    "detail"},
        {TimestampRole, "timestamp"},
        {LatchedRole,   "latched"},
        {ActiveRole, "active"},
        {AcknowledgedRole, "acknowledged"},
        {ResolvedAtRole, "resolvedAt"},
        {OccurrencesRole, "occurrences"},
        {DedupeKeyRole, "dedupeKey"},
    };
}

QVariant AeroAlertModel::data(const QModelIndex &idx, int role) const
{
    if (!idx.isValid() || idx.row() < 0 || idx.row() >= m_alerts.size()) {
        return {};
    }
    const AeroAlert &a = m_alerts.at(idx.row());
    switch (static_cast<AlertRole>(role)) {
    case IdRole:        return a.id;
    case PriorityRole:  return priorityToString(a.priority);
    case SourceRole:    return a.source;
    case MessageRole:   return a.message;
    case DetailRole:    return a.detail;
    case TimestampRole: return a.timestamp.toMSecsSinceEpoch();
    case LatchedRole:   return a.latched;
    case ActiveRole: return a.active;
    case AcknowledgedRole: return a.acknowledged;
    case ResolvedAtRole: return a.resolvedAtMs;
    case OccurrencesRole: return a.occurrences;
    case DedupeKeyRole: return m_keysById.value(a.id);
    }
    return {};
}

// ---------------------------------------------------------------------------
// Properties
// ---------------------------------------------------------------------------

int AeroAlertModel::unreadCount() const
{
    int n = 0;
    for (const AeroAlert &a : m_alerts) {
        if (!a.acknowledged) {
            ++n;
        }
    }
    return n;
}

bool AeroAlertModel::hasCritical() const
{
    for (const AeroAlert &a : m_alerts) {
        if (a.active && a.priority == AlertPriority::Critical) {
            return true;
        }
    }
    return false;
}

int AeroAlertModel::activeCount() const
{
    int count = 0;
    for (const AeroAlert &alert : m_alerts) {
        count += alert.active ? 1 : 0;
    }
    return count;
}

// ---------------------------------------------------------------------------
// Q_INVOKABLE — alert management
// ---------------------------------------------------------------------------

void AeroAlertModel::addAlert(const QString &priority, const QString &source,
                               const QString &message, const QString &detail, bool latch)
{
    raiseAlert(source + QStringLiteral(":") + message, priority, source, message, detail, latch);
}

QString AeroAlertModel::raiseAlert(const QString &dedupeKey, const QString &priority, const QString &source,
                                   const QString &message, const QString &detail, bool latch)
{
    const AlertPriority p = priorityFromString(priority);
    const QString key = dedupeKey.isEmpty() ? source + QStringLiteral(":") + message : dedupeKey;
    for (int i = 0; i < m_alerts.size(); ++i) {
        AeroAlert &existing = m_alerts[i];
        if (m_keysById.value(existing.id) != key || !existing.active) {
            continue;
        }
        const bool criticalBefore = hasCritical();
        existing.priority = p;
        existing.source = source;
        existing.message = message;
        existing.detail = detail;
        existing.timestamp = QDateTime::currentDateTimeUtc();
        existing.latched = existing.latched || latch || p == AlertPriority::Critical;
        existing.acknowledged = false;
        ++existing.occurrences;
        const QModelIndex modelIndex = index(i);
        emit dataChanged(modelIndex, modelIndex);
        emit unreadCountChanged();
        if (criticalBefore != hasCritical()) emit hasCriticalChanged();
        return existing.id;
    }

    AeroAlert alert;
    alert.id        = QUuid::createUuid().toString(QUuid::WithoutBraces);
    alert.priority  = p;
    alert.source    = source;
    alert.message   = message;
    alert.detail    = detail;
    alert.timestamp = QDateTime::currentDateTimeUtc();
    alert.latched   = latch || (p == AlertPriority::Critical);

    const bool wasCritical = hasCritical();

    // Insert at position 0 (newest first).
    beginInsertRows({}, 0, 0);
    m_alerts.prepend(alert);
    m_keysById.insert(alert.id, key);
    endInsertRows();

    // Enforce max size of 200: remove oldest non-critical, non-latched entry.
    if (m_alerts.size() > 200) {
        for (int i = m_alerts.size() - 1; i >= 1; --i) {
            const AeroAlert &candidate = m_alerts.at(i);
            if (!candidate.active && !candidate.latched) {
                m_keysById.remove(candidate.id);
                beginRemoveRows({}, i, i);
                m_alerts.removeAt(i);
                endRemoveRows();
                break;
            }
        }
    }

    emit newAlert(priority, source, message);
    emit unreadCountChanged();

    if (hasCritical() != wasCritical) {
        emit hasCriticalChanged();
    }
    emit activeCountChanged();
    return alert.id;
}

void AeroAlertModel::resolveAlert(const QString &dedupeKey)
{
    for (int i = 0; i < m_alerts.size(); ++i) {
        if (m_keysById.value(m_alerts.at(i).id) == dedupeKey && m_alerts.at(i).active) {
            const bool criticalBefore = hasCritical();
            m_alerts[i].active = false;
            m_alerts[i].resolvedAtMs = currentMs();
            const QModelIndex mi = index(i);
            emit dataChanged(mi, mi, {ActiveRole, ResolvedAtRole});
            emit activeCountChanged();
            if (criticalBefore != hasCritical()) emit hasCriticalChanged();
        }
    }
}

void AeroAlertModel::acknowledge(const QString &id)
{
    for (int i = 0; i < m_alerts.size(); ++i) {
        if (m_alerts.at(i).id == id && !m_alerts.at(i).acknowledged) {
            m_alerts[i].acknowledged = true;
            emit dataChanged(index(i), index(i), {AcknowledgedRole});
            emit unreadCountChanged();
            return;
        }
    }
}

void AeroAlertModel::acknowledgeAll()
{
    bool changed = false;
    for (AeroAlert &alert : m_alerts) {
        if (!alert.acknowledged) { alert.acknowledged = true; changed = true; }
    }
    if (changed) {
        emit dataChanged(index(0), index(m_alerts.size() - 1), {AcknowledgedRole});
        emit unreadCountChanged();
    }
}

void AeroAlertModel::clearOlderThan(int seconds)
{
    const qint64 cutoff = QDateTime::currentMSecsSinceEpoch() - static_cast<qint64>(seconds) * 1000;
    bool criticalChanged = false;
    // Iterate from back to front to preserve indices.
    for (int i = m_alerts.size() - 1; i >= 0; --i) {
        const AeroAlert &a = m_alerts.at(i);
        if (!a.active && !a.latched && a.timestamp.toMSecsSinceEpoch() < cutoff) {
            m_keysById.remove(a.id);
            beginRemoveRows({}, i, i);
            m_alerts.removeAt(i);
            endRemoveRows();
        }
    }
    emit unreadCountChanged();
    emit activeCountChanged();
    if (criticalChanged) {
        emit hasCriticalChanged();
    }
}

void AeroAlertModel::clearMessages()
{
    if (m_alerts.isEmpty()) {
        return;
    }
    const bool wasCritical = hasCritical();
    beginResetModel();
    m_keysById.clear();
    m_alerts.clear();
    endResetModel();
    emit unreadCountChanged();
    emit activeCountChanged();
    if (wasCritical) {
        emit hasCriticalChanged();
    }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

AlertPriority AeroAlertModel::priorityFromString(const QString &s) const
{
    if (s.compare(QLatin1String("Critical"), Qt::CaseInsensitive) == 0)  return AlertPriority::Critical;
    if (s.compare(QLatin1String("Warning"),  Qt::CaseInsensitive) == 0)  return AlertPriority::Warning;
    if (s.compare(QLatin1String("Mission"),  Qt::CaseInsensitive) == 0)  return AlertPriority::Mission;
    if (s.compare(QLatin1String("System"),   Qt::CaseInsensitive) == 0)  return AlertPriority::System;
    return AlertPriority::Info;
}

QString AeroAlertModel::priorityToString(AlertPriority p) const
{
    switch (p) {
    case AlertPriority::Critical: return QStringLiteral("Critical");
    case AlertPriority::Warning:  return QStringLiteral("Warning");
    case AlertPriority::Mission:  return QStringLiteral("Mission");
    case AlertPriority::System:   return QStringLiteral("System");
    case AlertPriority::Info:
    default:                      return QStringLiteral("Info");
    }
}

qint64 AeroAlertModel::currentMs() const
{
    return QDateTime::currentMSecsSinceEpoch();
}

