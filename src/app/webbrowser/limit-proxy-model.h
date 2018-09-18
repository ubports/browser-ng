/*
 * Copyright 2014-2015 Canonical Ltd.
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

#ifndef __LIMIT_PROXY_MODEL_H__
#define __LIMIT_PROXY_MODEL_H__

// Qt
#include <QtCore/QIdentityProxyModel>

class LimitProxyModel : public QIdentityProxyModel
{
    Q_OBJECT

    Q_PROPERTY(QObject* sourceModel READ sourceModel WRITE setSourceModel NOTIFY sourceModelChanged)
    Q_PROPERTY(int limit READ limit WRITE setLimit NOTIFY limitChanged)
    Q_PROPERTY(int count READ rowCount NOTIFY countChanged)
    Q_PROPERTY(int unlimitedCount READ unlimitedRowCount NOTIFY unlimitedCountChanged)

public:
    LimitProxyModel(QObject* parent=0);

    QAbstractItemModel* sourceModel() const;
    void setSourceModel(QObject* sourceModel);

    int limit() const;
    void setLimit(int limit);

    int rowCount(const QModelIndex &parent = QModelIndex()) const;
    int unlimitedRowCount(const QModelIndex &parent = QModelIndex()) const;

    Q_INVOKABLE QVariantMap get(int index) const;

Q_SIGNALS:
    void sourceModelChanged() const;
    void limitChanged() const;
    void unlimitedCountChanged();
    void countChanged();

private Q_SLOTS:
    void sourceRowsAboutToBeInserted(const QModelIndex &parent, int start, int
end);
    void sourceRowsAboutToBeRemoved(const QModelIndex &parent, int start, int
end);
    void sourceRowsInserted(const QModelIndex &parent, int start, int end);
    void sourceRowsRemoved(const QModelIndex &parent, int start, int end);

private:
    int m_limit;
    bool m_sourceInserting;
    bool m_sourceRemoving;
    int m_dataChangedBegin;
    int m_dataChangedEnd;
};

#endif // __LIMIT_PROXY_MODEL_H__
