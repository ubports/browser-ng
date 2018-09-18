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

#ifndef __BOOKMARKS_FOLDERLIST_MODEL_H__
#define __BOOKMARKS_FOLDERLIST_MODEL_H__

// Qt
#include <QtCore/QAbstractListModel>
#include <QtCore/QMap>
#include <QtCore/QString>

class BookmarksFolderModel;
class BookmarksModel;

class BookmarksFolderListModel : public QAbstractListModel
{
    Q_OBJECT

    Q_PROPERTY(BookmarksModel* sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)

    Q_ENUMS(Roles)

public:
    BookmarksFolderListModel(QObject* parent=0);
    ~BookmarksFolderListModel();

    enum Roles {
        Folder = Qt::UserRole + 1,
        Entries
    };

    // reimplemented from QAbstractListModel
    QHash<int, QByteArray> roleNames() const;
    int rowCount(const QModelIndex& parent=QModelIndex()) const;
    QVariant data(const QModelIndex& index, int role) const;

    BookmarksModel* sourceModel() const;
    void setSourceModel(BookmarksModel* sourceModel);

    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int indexOf(const QString& folder) const;
    Q_INVOKABLE void createNewFolder(const QString& folder);

Q_SIGNALS:
    void sourceModelChanged() const;
    void countChanged() const;

private Q_SLOTS:
    void onFolderAdded(const QString& folder);
    void onModelReset();

    void onFolderDataChanged();

private:
    BookmarksModel* m_sourceModel;
    QMap<QString, BookmarksFolderModel*> m_folders;

    bool checkValidFolderIndex(int row) const;
    void clearFolders();
    void populateModel();
    void addFolder(const QString& folder);
    void emitDataChanged(const QString& folder);
};

#endif // __BOOKMARKS_FOLDERLIST_MODEL_H__
