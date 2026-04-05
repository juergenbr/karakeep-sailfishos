#ifdef QT_QML_DEBUG
#include <QtQuick>
#endif

#include "api/appsettings.h"
#include "api/karakeepapi.h"

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <sailfishapp.h>

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    QScopedPointer<QQuickView> view(SailfishApp::createView());

    AppSettings *settings = new AppSettings(app.data());
    KarakeepApi *api = new KarakeepApi(settings, app.data());

    view->rootContext()->setContextProperty("AppSettings", settings);
    view->rootContext()->setContextProperty("KarakeepApi", api);

    view->setSource(SailfishApp::pathTo("qml/harbour-karakeep.qml"));
    view->show();

    return app->exec();
}
