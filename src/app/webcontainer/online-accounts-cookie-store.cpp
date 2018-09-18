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

#include "online-accounts-cookie-store.h"

#include <QList>
#include <QVariant>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDebug>


#if defined(ONLINE_ACCOUNTS_COOKIE_STORE_OBJECT)
#   error ONLINE_ACCOUNTS_COOKIE_STORE_OBJECT already defined
#else
#   define ONLINE_ACCOUNTS_COOKIE_STORE_OBJECT "com.nokia.singlesignonui"
#endif

#if defined(ONLINE_ACCOUNTS_COOKIE_STORE_PATH)
#   error ONLINE_ACCOUNTS_COOKIE_STORE_PATH already defined
#else
#   define ONLINE_ACCOUNTS_COOKIE_STORE_PATH "/SignonUi"
#endif

#if defined(ONLINE_ACCOUNTS_COOKIE_STORE_METHOD)
#   error ONLINE_ACCOUNTS_COOKIE_STORE_METHOD already defined
#else
#   define ONLINE_ACCOUNTS_COOKIE_STORE_METHOD "cookiesForIdentity"
#endif

class OnlineAccountsCookieStorePrivate
{
public:
    OnlineAccountsCookieStorePrivate():
        _id(0),
        m_connection(QDBusConnection::sessionBus())
    {}

    quint32 _id;
    QDBusConnection m_connection;
};


OnlineAccountsCookieStore::OnlineAccountsCookieStore(QObject *parent)
    : CookieStore(parent),
      d_ptr(new OnlineAccountsCookieStorePrivate())
{
    qDBusRegisterMetaType<OnlineAccountsCookies>();
}

OnlineAccountsCookieStore::~OnlineAccountsCookieStore()
{
    delete d_ptr;
}

quint32 OnlineAccountsCookieStore::accountId () const
{
    Q_D(const OnlineAccountsCookieStore);
    return d->_id;
}

void OnlineAccountsCookieStore::setAccountId (quint32 id)
{
    Q_D(OnlineAccountsCookieStore);

    if (accountId() != id)
    {
        d->_id = id;
        Q_EMIT accountIdChanged();
    }
}

void OnlineAccountsCookieStore::doGetCookies()
{
    Q_D(const OnlineAccountsCookieStore);

    QDBusMessage message =
        QDBusMessage::createMethodCall(ONLINE_ACCOUNTS_COOKIE_STORE_OBJECT,
                                       ONLINE_ACCOUNTS_COOKIE_STORE_PATH,
                                       ONLINE_ACCOUNTS_COOKIE_STORE_OBJECT,
                                       ONLINE_ACCOUNTS_COOKIE_STORE_METHOD);

    message.setArguments(QVariantList() << accountId());

    QDBusMessage reply = d->m_connection.call(message);

    if (reply.type() == QDBusMessage::ErrorMessage)
    {
        qWarning() << "Got error:" << reply.errorMessage();
        emit gotCookies(Cookies());
    }

    QList<QVariant> arguments = reply.arguments();

    if ( ! arguments.count())
    {
        qWarning() << "Invalid number arguments to get online accounts cookies call.";
        emit gotCookies(Cookies());
    }

    if (arguments.count() > 1)
    {
        qint64 timeStamp = arguments.at(1).toLongLong();
        if (timeStamp != 0)
        {
            qDebug() << "Got a cookie timestamp of"
                     << timeStamp
                     << "from Online Accounts DBUS cookiesForIdentity() call.";

            QDateTime t = QDateTime::fromMSecsSinceEpoch(timeStamp * 1000);
            updateLastUpdateTimestamp(t);
        }
    }

    emit gotCookies(fromDbusCookies(qdbus_cast<OnlineAccountsCookies>(arguments.front())));
}

Cookies OnlineAccountsCookieStore::fromDbusCookies(const OnlineAccountsCookies& cookies)
{
    Cookies parsedCookies;
    Q_FOREACH(const QByteArray &cookie, cookies) {
        parsedCookies.append(QNetworkCookie::parseCookies(cookie));
    }
    return parsedCookies;
}

void OnlineAccountsCookieStore::doSetCookies(const Cookies& cookies)
{
    Q_UNUSED(cookies);
}
