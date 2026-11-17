#include <QGuiApplication>
#include <QQuickWindow>
#include <QQmlApplicationEngine>
#include <QTimer>
#include <QUrl>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.loadFromModule("PerspectiveNVP", "Main");
    if (engine.rootObjects().isEmpty()) return -1;
    if (qEnvironmentVariableIsSet("PERSPECTIVE_SCREENSHOT")) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        const QString path = qEnvironmentVariable("PERSPECTIVE_SCREENSHOT");
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_TRANSITION")) {
            auto *slider = window->findChild<QObject *>("progressSlider");
            if (slider)
                slider->setProperty("value",
                                    qEnvironmentVariable("PERSPECTIVE_TEST_TRANSITION").toDouble());
        }
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_VP3_Y_OFFSET")) {
            auto *vp = window->findChild<QObject *>("vp3");
            if (vp)
                vp->setProperty("y", vp->property("y").toDouble()
                                  + qEnvironmentVariable("PERSPECTIVE_TEST_VP3_Y_OFFSET").toDouble());
        }
        QTimer::singleShot(1500, window, [window, path]() {
            if (!window->grabWindow().save(path))
                qWarning("Could not save screenshot");
            QGuiApplication::quit();
        });
    }
    return app.exec();
}
