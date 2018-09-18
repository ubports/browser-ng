/*
 * Copyright 2013-2016 Canonical Ltd.
 *
 * This file is part of morph-browser.
 *
 * morph-browser is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * morph-browser is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __WEBAPP_CONTAINER_H__
#define __WEBAPP_CONTAINER_H__

#include "browserapplication.h"

// Qt
#include <QString>
#include <QStringList>
#include <QScopedPointer>

class SchemeFilter;
class QQmlContext;
class WebappContainerHelper;

class WebappContainer : public BrowserApplication
{
    Q_OBJECT

public:
    WebappContainer(int& argc, char** argv);

    bool initialize();

protected:
    void qmlEngineCreated(QQmlEngine *);
    virtual QList<QUrl> urls() const;

private:
    void printUsage() const final;
    void earlyEnvironment();
    void parseCommandLine();
    void parseExtraConfiguration();
    QString getExtraWebappUrlPatterns() const;
    bool isValidLocalApplicationRunningContext() const;
    bool isValidLocalResource(const QString& resourceName) const;
    bool shouldNotValidateCommandLineUrls() const;
    bool isValidLocalIntentFilterFile(const QString& filename) const;
    void setupLocalSchemeFilterIfAny(QQmlContext* context, const QString& webappSearchPath);
    QString appId() const;

private Q_SLOTS:
    void onNewInstanceLaunched(const QStringList& arguments) const final;

private:
    QString m_webappName;
    QString m_webappIcon;
    QString m_webappModelSearchPath;
    QStringList m_webappUrlPatterns;
    QString m_accountProvider;
    bool m_accountSwitcher;
    bool m_storeSessionCookies;
    bool m_backForwardButtonsVisible;
    bool m_addressBarVisible;
    bool m_localWebappManifest;
    bool m_openExternalUrlInOverlay;
    QString m_popupRedirectionUrlPrefixPattern;
    QString m_localCookieStoreDbPath;
    QString m_userAgentOverride;
    QScopedPointer<WebappContainerHelper> m_webappContainerHelper;
    QScopedPointer<SchemeFilter> m_schemeFilter;
    QString m_defaultVideoCaptureCameraPosition;
    bool m_fullscreen;
    bool m_maximized;

    static const QString URL_PATTERN_SEPARATOR;
    static const QString LOCAL_SCHEME_FILTER_FILENAME;
};

#endif // __WEBAPP_CONTAINER_H__
