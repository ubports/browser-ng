/*
 * Copyright 2015-2016 Canonical Ltd.
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

#ifndef __DOWNLOADS_MODEL_H__
#define __DOWNLOADS_MODEL_H__

#include <QtCore/QAbstractListModel>
#include <QtCore/QDateTime>
#include <QtCore/QList>
#include <QtCore/QSet>
#include <QtCore/QString>
#include <QtCore/QUrl>
#include <QtSql/QSqlDatabase>

class DownloadsModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(QString databasePath READ databasePath WRITE setDatabasePath NOTIFY databasePathChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY rowCountChanged)

    Q_ENUMS(Roles)

public:
    DownloadsModel(QObject* parent=0);
    ~DownloadsModel();

    enum Roles {
        DownloadId = Qt::UserRole + 1,
        Url,
        Path,
        Filename,
        Mimetype,
        Complete,
        Paused,
        Error,
        Created,
        Incognito
    };

    // reimplemented from QAbstractListModel
    QHash<int, QByteArray> roleNames() const;
    int rowCount(const QModelIndex& parent=QModelIndex()) const;
    QVariant data(const QModelIndex& index, int role) const;
    bool canFetchMore(const QModelIndex &parent = QModelIndex()) const;
    void fetchMore(const QModelIndex &parent = QModelIndex());

    const QString databasePath() const;
    void setDatabasePath(const QString& path);

    Q_INVOKABLE bool contains(const QString& downloadId) const;
    Q_INVOKABLE void add(const QString& downloadId, const QUrl& url, const QString& path, const QString& mimetype, bool incognito);
    Q_INVOKABLE void setComplete(const QString& downloadId, const bool complete);
    Q_INVOKABLE void setError(const QString& downloadId, const QString& error);
    Q_INVOKABLE void deleteDownload(const QString& path);
    Q_INVOKABLE void cancelDownload(const QString& downloadId);
    Q_INVOKABLE void pauseDownload(const QString& downloadId);
    Q_INVOKABLE void resumeDownload(const QString& downloadId);
    Q_INVOKABLE void pruneIncognitoDownloads();

Q_SIGNALS:
    void databasePathChanged() const;
    void rowCountChanged();

private:
    QSqlDatabase m_database;
    int m_numRows;
    int m_fetchedCount;
    bool m_canFetchMore;

    struct DownloadEntry {
        QString downloadId;
        QUrl url;
        QString path;
        QString filename;
        QString mimetype;
        bool complete;
        bool paused;
        QString error;
        QDateTime created;
        bool incognito;
    };
    QList<DownloadEntry> m_orderedEntries;

    void resetDatabase(const QString& databaseName);
    void createOrAlterDatabaseSchema();
    void insertNewEntryInDatabase(const DownloadEntry& entry);
    void removeExistingEntryFromDatabase(const QString& path);
    void setPaused(const QString& downloadId, bool paused);
    int getIndexForDownloadId(const QString& downloadId) const;
};

#endif // __DOWNLOADS_MODEL_H__
