import sys

path = '/home/deepa/AeroTHON-GCS-V2/src/Utilities/Audio/AudioOutput.cc'
with open(path, 'r') as f:
    content = f.read()

# Add QProcess
if '<QProcess>' not in content:
    content = content.replace('#include <QTimer>', '#include <QTimer>\n#include <QProcess>')

# 1. Patch say()
say_start = content.find('void AudioOutput::say(const QString &text, TextMods textMods)')
say_end = content.find('void AudioOutput::sayAlert(const QString &text)')

new_say = '''void AudioOutput::say(const QString &text, TextMods textMods)
{
    if (!_initialized || _volumeSetting() <= 0.0 || _mutedSetting() || !_speakCapable) return;
    QString outText = _fixTextMessageForAudio(text);
    if (textMods.testFlag(TextMod::Translate)) outText = tr("%1").arg(outText);
    if (outText.isEmpty()) return;

#ifdef Q_OS_LINUX
    QProcess* proc = new QProcess();
    proc->start("sh", {"-c", "espeak-ng -s 150 --stdout | pw-play -"});
    proc->write(outText.toUtf8());
    proc->closeWriteChannel();
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), proc, &QObject::deleteLater);
#else
    (void) QMetaObject::invokeMethod(_engine, [this, outText]() {
        if (_textQueueSize >= kMaxTextQueueSize) { _engine->stop(QTextToSpeech::BoundaryHint::Immediate); _textQueueSize = 0; }
        if (_engine->enqueue(outText) >= 0) _textQueueSize++;
    });
#endif
}

'''

# 2. Patch sayAlert()
say_alert_end = content.find('void AudioOutput::sayPeriodic(const QString &text)')
new_say_alert = '''void AudioOutput::sayAlert(const QString &text)
{
    const QString normalizedText = text.simplified();
    if (normalizedText.isEmpty()) return;
    const auto repeatCooldownMs = std::chrono::duration_cast<std::chrono::milliseconds>(kAlertRepeatCooldown).count();
    if (_lastAlertText == normalizedText && _lastAlertTimer.isValid() && _lastAlertTimer.elapsed() < repeatCooldownMs) return;

    _lastAlertText = normalizedText;
    _lastAlertTimer.restart();

    if (!_initialized || _volumeSetting() <= 0.0 || _mutedSetting() || !_speakCapable) return;
    const QString outText = _fixTextMessageForAudio(normalizedText);

#ifdef Q_OS_LINUX
    QProcess* proc = new QProcess();
    proc->start("sh", {"-c", "espeak-ng -s 150 --stdout | pw-play -"});
    proc->write(outText.toUtf8());
    proc->closeWriteChannel();
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), proc, &QObject::deleteLater);
#else
    (void) QMetaObject::invokeMethod(_engine, [this, outText]() {
        _engine->stop(QTextToSpeech::BoundaryHint::Immediate);
        _textQueueSize = 0;
        _engine->say(outText);
    });
#endif
}

'''

# 3. Patch sayPeriodic()
say_periodic_end = content.find('void AudioOutput::testAudioOutput()')
new_say_periodic = '''void AudioOutput::sayPeriodic(const QString &text)
{
    if (!_initialized || _volumeSetting() <= 0.0 || _mutedSetting() || !_speakCapable || text.trimmed().isEmpty()) return;
    const QString outText = _fixTextMessageForAudio(text);

#ifdef Q_OS_LINUX
    QProcess* proc = new QProcess();
    proc->start("sh", {"-c", "espeak-ng -s 150 --stdout | pw-play -"});
    proc->write(outText.toUtf8());
    proc->closeWriteChannel();
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), proc, &QObject::deleteLater);
#else
    (void) QMetaObject::invokeMethod(_engine, [this, outText]() {
        if (_engine->state() != QTextToSpeech::State::Ready || _textQueueSize > 0) return;
        if (_engine->enqueue(outText) >= 0) _textQueueSize++;
    });
#endif
}

'''

content = content[:say_start] + new_say + new_say_alert + new_say_periodic + content[say_periodic_end:]

with open(path, 'w') as f:
    f.write(content)
