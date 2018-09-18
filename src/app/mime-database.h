/*
 * Copyright 2015 Canonical Ltd.
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

#ifndef __MIME_DATABASE_H__
#define __MIME_DATABASE_H__

#include <QtCore/QMimeDatabase>
#include <QtCore/QObject>
#include <QtCore/QString>

class MimeDatabase : public QObject
{
    Q_OBJECT

public:
    explicit MimeDatabase(QObject* parent=0);

    Q_INVOKABLE QString filenameToMimeType(const QString& filename) const;
    Q_INVOKABLE QString iconForMimetype(const QString& mimetypeString) const;
    Q_INVOKABLE QString nameForMimetype(const QString& mimetypeString) const;


private:
    QMimeDatabase m_database;
};

#endif // __MIME_DATABASE_H__
