#include <QGuiApplication>
#include <QQuickWindow>
#include <QQuickItem>
#ifdef PAQ_HAVE_QT_TEST
#include <QTest>
#endif
#include <QQmlApplicationEngine>
#include <QTimer>
#include <QUrl>

static QQuickItem *findVisualItem(QQuickItem *root, const QString &name)
{
    if (root->objectName() == name) return root;
    for (auto *child : root->childItems())
        if (auto *found = findVisualItem(child, name)) return found;
    return nullptr;
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;
    engine.loadFromModule("PerspectiveNVP", "Main");
    if (engine.rootObjects().isEmpty()) return -1;
    if (qEnvironmentVariableIsSet("PERSPECTIVE_SCREENSHOT")) {
        auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());
        const QString path = qEnvironmentVariable("PERSPECTIVE_SCREENSHOT");
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_PRESET")) {
            auto *scene = window->findChild<QObject *>("sceneController");
            if (scene)
                scene->setProperty("presetKey", qEnvironmentVariable("PERSPECTIVE_TEST_PRESET"));
        }
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_TRANSITION")) {
            auto *slider = window->findChild<QObject *>("progressSlider");
            if (!slider) slider = window->findChild<QObject *>("workbenchTransition");
            if (slider)
                slider->setProperty("value",
                                    qEnvironmentVariable("PERSPECTIVE_TEST_TRANSITION").toDouble());
        }
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_SURFACE_MODE")) {
            auto *selector = window->findChild<QObject *>("surfaceModeSelector");
            if (selector)
                selector->setProperty("currentIndex",
                    qEnvironmentVariable("PERSPECTIVE_TEST_SURFACE_MODE")=="planar" ? 0 : 1);
        }
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_VP3_Y_OFFSET")) {
            auto *vp = window->findChild<QObject *>("vp3");
            if (vp)
                vp->setProperty("y", vp->property("y").toDouble()
                                  + qEnvironmentVariable("PERSPECTIVE_TEST_VP3_Y_OFFSET").toDouble());
        }
        #ifdef PAQ_HAVE_QT_TEST
        if (qEnvironmentVariableIsSet("PERSPECTIVE_TEST_DRAG_MARKER")) {
            QTimer::singleShot(300, window, [window]() {
                auto *marker = findVisualItem(window->contentItem(), "vpHandle0a");
                if (!marker || !marker->isVisible()) {
                    qFatal("Could not find visible VP handle for drag test");
                }
                const QPointF start = marker->mapToScene(
                    QPointF(marker->width()/2, marker->height()/2));
                const QPointF end = start + QPointF(55, 28);
                auto *scene = window->findChild<QObject *>("sceneController");
                const int revisionBefore = scene ? scene->property("geometryRevision").toInt() : -1;
                QTest::mouseMove(window, start.toPoint(), 20);
                QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier,
                                  start.toPoint(), 20);
                QTest::mouseMove(window, end.toPoint(), 20);
                QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier,
                                    end.toPoint(), 20);
                if (!scene || scene->property("geometryRevision").toInt() <= revisionBefore)
                    qFatal("VP drag did not update scene geometry revision");
                auto *surface = findVisualItem(window->contentItem(), "surface");
                if (!surface || surface->property("geometryRevision").toInt()
                                != scene->property("geometryRevision").toInt())
                    qFatal("VP drag did not update surface geometry revision");
            });
        }
        #endif
        QTimer::singleShot(1500, window, [window, path]() {
            if (!window->grabWindow().save(path))
                qWarning("Could not save screenshot");
            QGuiApplication::quit();
        });
    }
    return app.exec();
}
