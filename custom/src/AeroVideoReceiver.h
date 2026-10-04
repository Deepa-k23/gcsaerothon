#pragma once

#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QSize>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

class QQuickItem;
class VideoReceiver;

/// One persistent AeroTHON video stream backed by QGC's selected video backend.
///
/// The receiver and decoder are independent of panel geometry, so NORMAL,
/// EXPANDED, and FULLSCREEN transitions do not recreate the pipeline.
class AeroVideoReceiver : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString videoState READ videoState NOTIFY videoStateChanged)
    Q_PROPERTY(qreal currentFPS READ currentFPS NOTIFY currentFPSChanged)
    Q_PROPERTY(QString source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QObject *videoOutput READ videoOutput WRITE setVideoOutput NOTIFY videoOutputChanged)
    Q_PROPERTY(QSize videoSize READ videoSize NOTIFY videoSizeChanged)
    Q_PROPERTY(bool recentFrames READ recentFrames NOTIFY recentFramesChanged)

public:
    explicit AeroVideoReceiver(QObject *parent = nullptr);
    ~AeroVideoReceiver() override;

    QString videoState() const { return _videoState; }
    qreal currentFPS() const { return _currentFPS; }
    QString source() const { return _source; }
    QObject *videoOutput() const;
    QSize videoSize() const { return _videoSize; }
    bool recentFrames() const { return _recentFrames; }

    void setSource(const QString &source);
    void setVideoOutput(QObject *videoOutput);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

signals:
    void videoStateChanged();
    void currentFPSChanged();
    void sourceChanged();
    void videoOutputChanged();
    void videoSizeChanged();
    void recentFramesChanged();

private:
    void _ensureReceiver();
    void _destroyReceiver();
    void _setVideoState(const QString &state);
    void _setRecentFrames(bool recentFrames);
    void _scheduleStartRetry();
    void _connectFrameCounter();

    QString _videoState{QStringLiteral("NO SIGNAL")};
    qreal _currentFPS = 0.0;
    QString _source;
    QPointer<QQuickItem> _videoOutput;
    QSize _videoSize;
    VideoReceiver *_receiver = nullptr;
    void *_sink = nullptr;
    QTimer _retryTimer;
    int _retryAttempt = 0;
    quint64 _lastFrameCount = 0;
    bool _recentFrames = false;
    bool _stopRequested = false;
};
