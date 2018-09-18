/*
 * Copyright 2014, 2016 Canonical Ltd.
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

#ifndef WEBAPPCONTAINERHELPER_H
#define WEBAPPCONTAINERHELPER_H

#include <QUrl>
#include <QObject>


class WebappContainerHelper : public QObject
{
    Q_OBJECT

public:
    WebappContainerHelper(QObject* parent = 0);
    ~WebappContainerHelper();

    /**
     * Expects a CSS color string http://www.w3schools.com/css/css_colors.asp
     * and returns a rr,gg,bb formatted string.
     *
     * If the provided string is not a valid CSS color string, an empty string
     * is returned.
     */
    Q_INVOKABLE QString rgbColorFromCSSColor(const QString& cssColor);

private Q_SLOTS:

    void browseToUrl(QObject* webview, const QUrl& url);

Q_SIGNALS:

    void browseToUrlRequested(QObject* webview, const QUrl& url);
};

#endif // WEBAPPCONTAINERHELPER_H
