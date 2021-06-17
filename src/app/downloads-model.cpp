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

#include "downloads-model.h"

#include <QtCore/QDebug>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QMimeDatabase>
#include <QtCore/QMimeType>
#include <QtCore/QStandardPaths>
#include <QtSql/QSqlQuery>

#define CONNECTION_NAME "morph-browser-downloads"

/*!
    \class DownloadsModel
    \brief List model that stores information about downloaded files.

    DownloadsModel is a list model that stores information about files that
    have been downloaded by the browser and stored permanently 
    (e.g. in ~/Downloads), as opposed to those that were sent directly to
    another application after download. For each download the original URL, the
    path to the downloaded file, the file mimetype and the download time are 
    stored. The model is sorted chronologically to display the most recent 
    download first.

    The information is persistently stored on disk in a SQLite database.
    The database is read at startup to populate the model, and whenever a new
    entry is added to the model or an entry is removed from the model
    the database is updated. Removing a download from the model also results
    in it being deleted from the disk.
    The model doesn’t monitor the database for external changes, but does check
    that downloaded files still exist when first populating.
*/
DownloadsModel::DownloadsModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_numRows(0)
    , m_fetchedCount(0)
    , m_canFetchMore(true)
{
    m_database = QSqlDatabase::addDatabase(QLatin1String("QSQLITE"), CONNECTION_NAME);
}

DownloadsModel::~DownloadsModel()
{
    m_database.close();
    m_database = QSqlDatabase();
    QSqlDatabase::removeDatabase(CONNECTION_NAME);
}

void DownloadsModel::resetDatabase(const QString& databaseName)
{
    beginResetModel();
    m_orderedEntries.clear();
    m_database.close();
    m_database.setDatabaseName(databaseName);
    m_database.open();
    m_numRows = 0;
    m_fetchedCount = 0;
    m_canFetchMore = true;
    createOrAlterDatabaseSchema();
    endResetModel();
    Q_EMIT rowCountChanged();
}

void DownloadsModel::createOrAlterDatabaseSchema()
{
    QSqlQuery createQuery(m_database);
    QString query = QLatin1String("CREATE TABLE IF NOT EXISTS downloads "
                                  "(downloadId VARCHAR, url VARCHAR, path VARCHAR, "
                                  "mimetype VARCHAR, complete BOOL, paused BOOL, "
                                  "error VARCHAR, created DATETIME DEFAULT "
                                  "CURRENT_TIMESTAMP);");
    createQuery.prepare(query);
    createQuery.exec();
}

void DownloadsModel::fetchMore(const QModelIndex &parent)
{
    QSqlQuery populateQuery(m_database);
    QString query = QLatin1String("SELECT downloadId, url, path, mimetype, "
                                  "complete, error, created, paused "
                                  "FROM downloads ORDER BY created DESC LIMIT 100 OFFSET ?;");
    populateQuery.prepare(query);
    populateQuery.addBindValue(m_fetchedCount);
    populateQuery.exec();
    int count = 0; // size() isn't supported on the sqlite backend
    while (populateQuery.next()) {
        DownloadEntry entry;
        entry.incognito = false;
        entry.downloadId = populateQuery.value(0).toString();
        entry.url = populateQuery.value(1).toUrl();
        entry.path = populateQuery.value(2).toString();
        entry.mimetype = populateQuery.value(3).toString();
        entry.complete = populateQuery.value(4).toBool();
        entry.error = populateQuery.value(5).toString();
        entry.created = QDateTime::fromTime_t(populateQuery.value(6).toInt());
        entry.paused = populateQuery.value(7).toBool();
        QFileInfo fileInfo(entry.path);
        if (fileInfo.exists()) {
            entry.filename = fileInfo.fileName();
        }

        // Only list a completed entry if its file exists, however we don't
        // remove the entry if the file is missing as it may be stored on a
        // removable medium like an SD card in the future, so could reappear.
        if (!entry.complete || fileInfo.exists()) {
            beginInsertRows(QModelIndex(), m_numRows, m_numRows);
            m_orderedEntries.append(entry);
            endInsertRows();
            m_numRows++;
        }
        count++;
    }
    m_fetchedCount += count;
    if (count == 0) {
        m_canFetchMore = false;
    }
}

QHash<int, QByteArray> DownloadsModel::roleNames() const
{
    static QHash<int, QByteArray> roles;
    if (roles.isEmpty()) {
        roles[DownloadId] = "downloadId";
        roles[Url] = "url";
        roles[Path] = "path";
        roles[Filename] = "filename";
        roles[Mimetype] = "mimetype";
        roles[Complete] = "complete";
        roles[Paused] = "paused";
        roles[Error] = "error";
        roles[Created] = "created";
        roles[Incognito] = "incognito";
    }
    return roles;
}

int DownloadsModel::rowCount(const QModelIndex& parent) const
{
    Q_UNUSED(parent);
    return m_orderedEntries.count();
}

QVariant DownloadsModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }
    const DownloadEntry& entry = m_orderedEntries.at(index.row());
    switch (role) {
    case DownloadId:
        return entry.downloadId;
    case Url:
        return entry.url;
    case Path:
        return entry.path;
    case Filename:
        return entry.filename;
    case Mimetype:
        return entry.mimetype;
    case Complete:
        return entry.complete;
    case Paused:
        return entry.paused;
    case Error:
        return entry.error;
    case Created:
        return entry.created;
    case Incognito:
        return entry.incognito;
    default:
        return QVariant();
    }
}

const QString DownloadsModel::databasePath() const
{
    return m_database.databaseName();
}

void DownloadsModel::setDatabasePath(const QString& path)
{
    if (path != databasePath()) {
        if (path.isEmpty()) {
            resetDatabase(":memory:");
        } else {
            resetDatabase(path);
        }
        Q_EMIT databasePathChanged();
    }
}

bool DownloadsModel::contains(const QString& downloadId) const
{
    Q_FOREACH(const DownloadEntry& entry, m_orderedEntries) {
        if (entry.downloadId == downloadId) {
            return true;
        }
    }
    return false;
}

/*!
    Add a download to the database. This should happen as soon as the download
    is started.
*/
void DownloadsModel::add(const QString& downloadId, const QUrl& url, const QString& path, const QString& mimetype, bool incognito)
{
    beginInsertRows(QModelIndex(), 0, 0);
    DownloadEntry entry;
    entry.downloadId = downloadId;
    entry.complete = false;
    entry.paused = false;
    entry.url = url;
    entry.mimetype = mimetype;
    entry.path = path;
    entry.incognito = incognito;
    m_orderedEntries.prepend(entry);
    m_numRows++;
    endInsertRows();
    Q_EMIT rowCountChanged();
    if (!incognito) {
        insertNewEntryInDatabase(entry);
        m_fetchedCount++;
    }
}

void DownloadsModel::setComplete(const QString& downloadId, const bool complete)
{
    int index = getIndexForDownloadId(downloadId);
    if (index != -1) {
        DownloadEntry& entry = m_orderedEntries[index];
        if (entry.complete == complete) {
            return;
        }
        QVector<int> updatedRoles;
        
        entry.complete = complete;
        updatedRoles.append(Complete);

        // Override reported mimetype from server with detected mimetype from file once downloaded
        if (complete && QFile::exists(entry.path))
        {
            QFileInfo fi(entry.path);
            QMimeDatabase mimeDatabase;
            QString mimetype = mimeDatabase.mimeTypeForFile(fi).name();
            if (mimetype != entry.mimetype) {
                entry.mimetype = mimetype;
                updatedRoles.append(Mimetype);
            }
        }
        
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << updatedRoles);
        if (!entry.incognito) {
            QSqlQuery query(m_database);
            static QString updateStatement = QLatin1String("UPDATE downloads SET complete=?, mimetype=? WHERE downloadId=?;");
            query.prepare(updateStatement);
            query.addBindValue(entry.complete);
            query.addBindValue(entry.mimetype);
            query.addBindValue(downloadId);
            query.exec();
        }
    }
}

void DownloadsModel::setError(const QString& downloadId, const QString& error)
{
    int index = getIndexForDownloadId(downloadId);
    if (index != -1) {
        DownloadEntry& entry = m_orderedEntries[index];
        if (entry.error == error) {
            return;
        }
        entry.error = error;
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << Error);
        if (!entry.incognito) {
            QSqlQuery query(m_database);
            static QString updateStatement = QLatin1String("UPDATE downloads SET error=? WHERE downloadId=?;");
            query.prepare(updateStatement);
            query.addBindValue(error);
            query.addBindValue(downloadId);
            query.exec();
        }
    }
}

void DownloadsModel::insertNewEntryInDatabase(const DownloadEntry& entry)
{
    QSqlQuery query(m_database);
    static QString insertStatement = QLatin1String("INSERT INTO downloads (downloadId, url, path, mimetype) VALUES (?, ?, ?, ?);");
    query.prepare(insertStatement);
    query.addBindValue(entry.downloadId);
    query.addBindValue(entry.url);
    query.addBindValue(entry.path);
    query.addBindValue(entry.mimetype);
    query.exec();
}

/*!
    Remove a downloaded file from the list of downloads and
    delete the file.
*/
void DownloadsModel::deleteDownload(const QString& path)
{
    int index = 0;
    Q_FOREACH(DownloadEntry entry, m_orderedEntries) {
        if (entry.path == path) {
            bool incognito = entry.incognito;
            beginRemoveRows(QModelIndex(), index, index);
            m_orderedEntries.removeAt(index);
            endRemoveRows();
            m_numRows--;
            Q_EMIT rowCountChanged();
            QFile::remove(path);
            if (!incognito) {
                removeExistingEntryFromDatabase(path);
                m_fetchedCount--;
            }
            return;
        } else {
            index++;
        }
    }
}

/*!
    Remove a cancelled download from the model and the database.
*/
void DownloadsModel::cancelDownload(const QString& downloadId)
{
    int index = getIndexForDownloadId(downloadId);
    if (index != -1) {
        const DownloadEntry& entry = m_orderedEntries.at(index);
        bool incognito = entry.incognito;
        beginRemoveRows(QModelIndex(), index, index);
        m_orderedEntries.removeAt(index);
        endRemoveRows();
        m_numRows--;
        Q_EMIT rowCountChanged();
        if (!incognito) {
            QSqlQuery query(m_database);
            static QString deleteStatement = QLatin1String("DELETE FROM downloads WHERE downloadId=?;");
            query.prepare(deleteStatement);
            query.addBindValue(downloadId);
            query.exec();
            m_fetchedCount--;
        }
    }
}

void DownloadsModel::setPaused(const QString& downloadId, bool paused)
{
    int index = getIndexForDownloadId(downloadId);
    if (index != -1) {
        DownloadEntry& entry = m_orderedEntries[index];
        if (entry.paused == paused) {
            return;
        }
        entry.paused = paused;
        Q_EMIT dataChanged(this->index(index, 0), this->index(index, 0), QVector<int>() << Paused);
        if (!entry.incognito) {
            QSqlQuery query(m_database);
            static QString pauseStatement = QLatin1String("UPDATE downloads SET paused=? WHERE downloadId=?;");
            query.prepare(pauseStatement);
            query.addBindValue(paused);
            query.addBindValue(downloadId);
            query.exec();
        }
    }
}

void DownloadsModel::pauseDownload(const QString& downloadId)
{
    setPaused(downloadId, true);
}

void DownloadsModel::resumeDownload(const QString& downloadId)
{
    setPaused(downloadId, false);
}

void DownloadsModel::pruneIncognitoDownloads()
{
    for (int i = m_orderedEntries.size() - 1; i >= 0; --i) {
        const DownloadEntry& entry = m_orderedEntries.at(i);
        if (entry.incognito) {
            beginRemoveRows(QModelIndex(), i, i);
            m_orderedEntries.removeAt(i);
            endRemoveRows();
            m_numRows--;
            Q_EMIT rowCountChanged();
        }
    }
}

void DownloadsModel::removeExistingEntryFromDatabase(const QString& path)
{
    QSqlQuery query(m_database);
    static QString deleteStatement = QLatin1String("DELETE FROM downloads WHERE path=?;");
    query.prepare(deleteStatement);
    query.addBindValue(path);
    query.exec();
}

bool DownloadsModel::canFetchMore(const QModelIndex &parent) const
{
    Q_UNUSED(parent)

    return m_canFetchMore;
}

int DownloadsModel::getIndexForDownloadId(const QString& downloadId) const
{
    int index = 0;
    Q_FOREACH(const DownloadEntry& entry, m_orderedEntries) {
        if (entry.downloadId == downloadId) {
            return index;
        } else {
            ++index;
        }
    }
    return -1;
}
