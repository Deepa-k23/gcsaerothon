#pragma once

#include <QtCore/QObject>
#include <QtQml/QQmlEngine>

class BatteryFactGroup;
class Fact;
class FactGroup;
class QJSEngine;
class Vehicle;

class AeroOperationalHealth : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool vehicleAvailable READ vehicleAvailable NOTIFY healthChanged)
    Q_PROPERTY(bool gpsAvailable READ gpsAvailable NOTIFY healthChanged)
    Q_PROPERTY(int gpsFix READ gpsFix NOTIFY healthChanged)
    Q_PROPERTY(int gpsSatellites READ gpsSatellites NOTIFY healthChanged)
    Q_PROPERTY(double gpsHdop READ gpsHdop NOTIFY healthChanged)
    Q_PROPERTY(QString gpsStatus READ gpsStatus NOTIFY healthChanged)
    Q_PROPERTY(bool ekfAvailable READ ekfAvailable NOTIFY healthChanged)
    Q_PROPERTY(QString ekfStatus READ ekfStatus NOTIFY healthChanged)
    Q_PROPERTY(bool ekfGpsGlitch READ ekfGpsGlitch NOTIFY healthChanged)
    Q_PROPERTY(bool ekfAccelError READ ekfAccelError NOTIFY healthChanged)
    Q_PROPERTY(double ekfHorizontalPositionRatio READ ekfHorizontalPositionRatio NOTIFY healthChanged)
    Q_PROPERTY(double ekfVerticalPositionRatio READ ekfVerticalPositionRatio NOTIFY healthChanged)
    Q_PROPERTY(bool batteryAvailable READ batteryAvailable NOTIFY healthChanged)
    Q_PROPERTY(double batteryPercent READ batteryPercent NOTIFY healthChanged)
    Q_PROPERTY(double batteryVoltage READ batteryVoltage NOTIFY healthChanged)
    Q_PROPERTY(int batteryChargeState READ batteryChargeState NOTIFY healthChanged)
    Q_PROPERTY(QString batteryStatus READ batteryStatus NOTIFY healthChanged)

public:
    explicit AeroOperationalHealth(QObject *parent = nullptr);
    static AeroOperationalHealth *instance();
    static AeroOperationalHealth *create(QQmlEngine *qmlEngine, QJSEngine *jsEngine);

    bool vehicleAvailable() const { return _vehicle != nullptr; }
    bool gpsAvailable() const { return _gpsAvailable; }
    int gpsFix() const { return _gpsFix; }
    int gpsSatellites() const { return _gpsSatellites; }
    double gpsHdop() const { return _gpsHdop; }
    QString gpsStatus() const { return _gpsStatus; }
    bool ekfAvailable() const { return _ekfAvailable; }
    QString ekfStatus() const { return _ekfStatus; }
    bool ekfGpsGlitch() const { return _ekfGpsGlitch; }
    bool ekfAccelError() const { return _ekfAccelError; }
    double ekfHorizontalPositionRatio() const { return _ekfHorizontalPositionRatio; }
    double ekfVerticalPositionRatio() const { return _ekfVerticalPositionRatio; }
    bool batteryAvailable() const { return _batteryAvailable; }
    double batteryPercent() const { return _batteryPercent; }
    double batteryVoltage() const { return _batteryVoltage; }
    int batteryChargeState() const { return _batteryChargeState; }
    QString batteryStatus() const { return _batteryStatus; }

signals:
    void healthChanged();

private:
    void setVehicle(Vehicle *vehicle);
    void connectFact(Fact *fact);
    void refreshBatteryBinding();
    void evaluate();
    void evaluateGps();
    void evaluateEkf();
    void evaluateBattery();
    void resetUnknown();

    Vehicle *_vehicle{nullptr};
    FactGroup *_gpsGroup{nullptr};
    FactGroup *_ekfGroup{nullptr};
    BatteryFactGroup *_battery{nullptr};
    bool _gpsAvailable{false};
    int _gpsFix{0};
    int _gpsSatellites{0};
    double _gpsHdop{0.};
    QString _gpsStatus{QStringLiteral("UNKNOWN")};
    bool _hadGpsFix{false};
    bool _ekfAvailable{false};
    QString _ekfStatus{QStringLiteral("UNKNOWN")};
    bool _ekfGpsGlitch{false};
    bool _ekfAccelError{false};
    double _ekfHorizontalPositionRatio{0.};
    double _ekfVerticalPositionRatio{0.};
    bool _batteryAvailable{false};
    double _batteryPercent{0.};
    double _batteryVoltage{0.};
    int _batteryChargeState{0};
    QString _batteryStatus{QStringLiteral("UNKNOWN")};
};
