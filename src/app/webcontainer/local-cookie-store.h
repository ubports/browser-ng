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

#ifndef LOCAL_COOKIE_STORE_H
#define LOCAL_COOKIE_STORE_H

#include "cookie-store.h"

#include <QSqlDatabase>

class LocalCookieStore : public CookieStore
{
    Q_OBJECT
    Q_PROPERTY(QString dbPath READ dbPath WRITE setDbPath NOTIFY dbPathChanged)

public:
    LocalCookieStore(QObject* parent = 0);

    void setDbPath(const QString& path);
    QString dbPath() const;

    QDateTime lastUpdateTimeStamp() const Q_DECL_OVERRIDE;

Q_SIGNALS:
    void dbPathChanged();

private:
    virtual void doGetCookies() Q_DECL_OVERRIDE;
    virtual void doSetCookies(const Cookies& cookies) Q_DECL_OVERRIDE;

    bool createDb();

private:
    QString m_dbPath;
    QSqlDatabase m_db;
};

#endif // LOCAL_COOKIE_STORE_H
