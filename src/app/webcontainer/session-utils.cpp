/*
 * Copyright 2014 Canonical Ltd.
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

#include "session-utils.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QStandardPaths>

static void createTimestampFile(const QFileInfo &timestampFile) {
    timestampFile.dir().mkpath(".");
    QFile file(timestampFile.filePath());
    file.open(QIODevice::WriteOnly);
}

/**
 * Returns whether this is the first time that the webapp "webappName" is run
 * in the current user's session.
 */
bool SessionUtils::firstRun(const QString &webappName) {
    /* Return true if this is the first time that the webapp "webappName" is
     * run in the current user's session. */

    /* If the application is running confined, the heuristics below won't work,
     * as the application hasn't access to the upstart session data. In that
     * case, let's skip all the checks and just return false.
     */
    if (!qEnvironmentVariableIsEmpty("APP_ID")) {
        return false;
    }

    if (Q_UNLIKELY(webappName.isEmpty())) {
        /* Assume first run */
        return true;
    }

    QString xdgRuntimeDir(QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation));
    QFileInfo timestampFile(QString("%1/webapp-container/%2.stamp").
                            arg(xdgRuntimeDir).arg(webappName));
    if (!timestampFile.exists()) {
        createTimestampFile(timestampFile);
        return true;
    }

    /* If the file stamp is there, it might be a stale file from a previous
     * session (XDG_RUNTIME_DIR is cleared only when rebooting, not when
     * logging out); in order to detect this situation, we compare the time of
     * the file with the time of when the user session started.
     * We use the upstart timestamp files to obtain the latter.
     */
    QDir upstartSessionDir(QString("%1/upstart/sessions").arg(xdgRuntimeDir));
    upstartSessionDir.setNameFilters(QStringList() << "*.session");
    /* We want the newest file there */
    upstartSessionDir.setSorting(QDir::Time);
    QFileInfoList sessionFiles = upstartSessionDir.entryInfoList();
    if (sessionFiles.isEmpty()) {
        /* This shouldn't happen in Unity; play safe and assume it's the first
         * run */
        return true;
    }

    const QFileInfo &lastSession = sessionFiles.first();
    if (timestampFile.lastModified() < lastSession.lastModified()) {
        createTimestampFile(timestampFile);
        return true;
    } else {
        return false;
    }
}

