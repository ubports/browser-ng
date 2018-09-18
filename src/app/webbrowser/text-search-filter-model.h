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

#ifndef TEXTSEARCHFILTERMODEL_H
#define TEXTSEARCHFILTERMODEL_H

// Qt
#include <QtCore/QAbstractItemModel>
#include <QtCore/QList>
#include <QtCore/QSortFilterProxyModel>
#include <QtCore/QString>
#include <QtCore/QStringList>
#include <QtCore/QVariant>

class TextSearchFilterModel : public QSortFilterProxyModel
{
    Q_OBJECT

    Q_PROPERTY(QVariant sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(QStringList terms READ terms WRITE setTerms NOTIFY termsChanged)
    Q_PROPERTY(QStringList searchFields READ searchFields WRITE setSearchFields NOTIFY searchFieldsChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)

public:
    TextSearchFilterModel(QObject* parent=0);

    QVariant sourceModel() const;
    void setSourceModel(QVariant sourceModel);

    int count() const;

    const QStringList& terms() const;
    void setTerms(const QStringList&);

    const QStringList& searchFields() const;
    void setSearchFields(const QStringList&);

Q_SIGNALS:
    void sourceModelChanged() const;
    void termsChanged() const;
    void searchFieldsChanged() const;
    void countChanged() const;

protected:
    // reimplemented from QSortFilterProxyModel
    bool filterAcceptsRow(int source_row, const QModelIndex& source_parent) const;

private:
    void updateSearchRoles(const QAbstractItemModel* model);

    QStringList m_terms;
    QStringList m_searchFields;
    QList<int> m_searchRoles;
};


#endif // TEXTSEARCHFILTERMODEL_H
