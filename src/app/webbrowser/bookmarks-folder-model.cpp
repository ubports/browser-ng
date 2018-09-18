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

#include "bookmarks-folder-model.h"
#include "bookmarks-model.h"

// Qt
#include <QtCore/QUrl>

/*!
    \class BookmarksFolderModel
    \brief Proxy model that filters the contents of a bookmarks model
           based on a folder name

    BookmarksFolderModel is a proxy model that filters the contents of a
    bookmarks model based on a folder name.

    An entry in the bookmarks model matches if it is stored in a folder
    with the same name that the filter folder name (case-sensitive
    comparison).

    When no folder name is set (null or empty string), all entries that
    are not stored in any folder match.
*/
BookmarksFolderModel::BookmarksFolderModel(QObject* parent)
    : QSortFilterProxyModel(parent)
{
}

BookmarksModel* BookmarksFolderModel::sourceModel() const
{
    return qobject_cast<BookmarksModel*>(QSortFilterProxyModel::sourceModel());
}

void BookmarksFolderModel::setSourceModel(BookmarksModel* sourceModel)
{
    if (sourceModel != this->sourceModel()) {
        QSortFilterProxyModel::setSourceModel(sourceModel);
        Q_EMIT sourceModelChanged();
        Q_EMIT countChanged();
    }
}

const QString& BookmarksFolderModel::folder() const
{
    return m_folder;
}

void BookmarksFolderModel::setFolder(const QString& folder)
{
    if (folder != m_folder) {
        m_folder = folder;
        invalidate();
        Q_EMIT folderChanged();
        Q_EMIT countChanged();
    }
}

int BookmarksFolderModel::count() const
{
    return rowCount();
}

QVariantMap BookmarksFolderModel::get(int row) const
{
    if (row < 0 || row >= rowCount()) {
        return QVariantMap();
    }

    QVariantMap res;
    QHash<int,QByteArray> names = roleNames();
    QHashIterator<int, QByteArray> i(names);

    while (i.hasNext()) {
        i.next();
        QModelIndex idx = index(row, 0);
        QVariant data = idx.data(i.key());
        res[i.value()] = data;
    }

    return res;
}

bool BookmarksFolderModel::filterAcceptsRow(int source_row, const QModelIndex& source_parent) const
{
    QModelIndex index = sourceModel()->index(source_row, 0, source_parent);
    QString folder = sourceModel()->data(index, BookmarksModel::Folder).toString();
    return (folder.compare(m_folder, Qt::CaseSensitive) == 0);
}
