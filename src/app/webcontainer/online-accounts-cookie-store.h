/*
 * Copyright 2013-2014 Canonical Ltd.
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

#ifndef ONLINE_ACCOUNTS_COOKIE_STORE_H
#define ONLINE_ACCOUNTS_COOKIE_STORE_H

#include <QList>
#include <QByteArray>

#include "cookie-store.h"

class OnlineAccountsCookieStorePrivate;

class OnlineAccountsCookieStore : public CookieStore
{
    Q_OBJECT
    Q_PROPERTY(quint32 accountId READ accountId WRITE setAccountId NOTIFY accountIdChanged)


public:
    OnlineAccountsCookieStore(QObject *parent = 0);
    ~OnlineAccountsCookieStore();

    quint32 accountId () const;
    void setAccountId (quint32);


Q_SIGNALS:

    void accountIdChanged();


private:

    typedef QList<QByteArray> OnlineAccountsCookies;

    virtual void doGetCookies() Q_DECL_OVERRIDE;
    virtual void doSetCookies(const Cookies& cookies) Q_DECL_OVERRIDE;

    static Cookies fromDbusCookies(const OnlineAccountsCookies& cookies);

private:

    OnlineAccountsCookieStorePrivate * d_ptr;
    Q_DECLARE_PRIVATE(OnlineAccountsCookieStore)
};

#endif // ONLINE_ACCOUNTS_COOKIE_STORE_H
