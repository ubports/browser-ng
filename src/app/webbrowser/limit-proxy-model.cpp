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

#include <QtCore/QAbstractItemModel>

#include "limit-proxy-model.h"

/*!
    \class LimitProxyModel
    \brief Identity model that limits the number of rows returned by a model

    LimitProxyModel is a proxy model that limits the number
    of rows returned by a model
    (i.e. only the first N entries are returned).

    This proxy model was copied from unity8's source tree with small changes,
    like the type of the sourceModel.
*/
LimitProxyModel::LimitProxyModel(QObject* parent)
    : QIdentityProxyModel(parent),
    m_limit(-1),
    m_sourceInserting(false),
    m_sourceRemoving(false),
    m_dataChangedBegin(-1),
    m_dataChangedEnd(-1)

{
    connect(this, SIGNAL(modelReset()), SIGNAL(countChanged()));
    connect(this, SIGNAL(rowsInserted(QModelIndex,int,int)), SIGNAL(countChanged()));
    connect(this, SIGNAL(rowsRemoved(QModelIndex,int,int)), SIGNAL(countChanged()));
    connect(this, SIGNAL(rowsInserted(QModelIndex,int,int)), SIGNAL(unlimitedCountChanged()));
    connect(this, SIGNAL(rowsRemoved(QModelIndex,int,int)), SIGNAL(unlimitedCountChanged()));
}

QAbstractItemModel* LimitProxyModel::sourceModel() const
{
    return qobject_cast<QAbstractItemModel*>(QIdentityProxyModel::sourceModel());
}

void LimitProxyModel::setSourceModel(QObject* sourceModel)
{
    QAbstractItemModel* model = qobject_cast<QAbstractItemModel*>(sourceModel);

    if (model != this->sourceModel()) {
        if (this->sourceModel() != NULL) {
            this->sourceModel()->disconnect(this);
        }

        QIdentityProxyModel::setSourceModel(model);

        if (this->sourceModel() != NULL) {
            // Disconnect the QIdentityProxyModel handling for rows removed/added...
            disconnect(this->sourceModel(), SIGNAL(rowsAboutToBeInserted(QModelIndex,int,int)), this, NULL);
            disconnect(this->sourceModel(), SIGNAL(rowsInserted(QModelIndex,int,int)), this, NULL);
            disconnect(this->sourceModel(), SIGNAL(rowsAboutToBeRemoved(QModelIndex,int,int)), this, NULL);
            disconnect(this->sourceModel(), SIGNAL(rowsRemoved(QModelIndex,int,int)), this, NULL);

            // ... and use our own
            connect(this->sourceModel(), SIGNAL(rowsAboutToBeInserted(QModelIndex,int,int)),
                    this, SLOT(sourceRowsAboutToBeInserted(QModelIndex,int,int)));
            connect(this->sourceModel(), SIGNAL(rowsInserted(QModelIndex,int,int)),
                    this, SLOT(sourceRowsInserted(QModelIndex,int,int)));
            connect(this->sourceModel(), SIGNAL(rowsAboutToBeRemoved(QModelIndex,int,int)),
                    this, SLOT(sourceRowsAboutToBeRemoved(QModelIndex,int,int)));
            connect(this->sourceModel(), SIGNAL(rowsRemoved(QModelIndex,int,int)),
                    this, SLOT(sourceRowsRemoved(QModelIndex,int,int)));
        }
        Q_EMIT sourceModelChanged();
    }
}

int LimitProxyModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) // We are not a tree
        return 0;

    const int unlimitedCount = QIdentityProxyModel::rowCount(parent);
    return m_limit < 0 ? unlimitedCount : qMin(m_limit, unlimitedCount);
}

int LimitProxyModel::unlimitedRowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) // We are not a tree
        return 0;

    return QIdentityProxyModel::rowCount(parent);
}

int LimitProxyModel::limit() const
{
    return m_limit;
}

void LimitProxyModel::setLimit(int limit)
{
    if (limit != m_limit) {
        bool inserting = false;
        bool removing = false;
        const int oldCount = rowCount();
        const int unlimitedCount = QIdentityProxyModel::rowCount();
        if (m_limit < 0) {
            if (limit < oldCount) {
                removing = true;
                beginRemoveRows(QModelIndex(), limit, oldCount - 1);
            }
        } else if (limit < 0) {
            if (m_limit < unlimitedCount) {
                inserting = true;
                beginInsertRows(QModelIndex(), m_limit, unlimitedCount - 1);
            }
        } else {
            if (limit > m_limit && unlimitedCount > m_limit) {
                inserting = true;
                beginInsertRows(QModelIndex(), m_limit, qMin(limit, unlimitedCount) - 1);
            } else if (limit < m_limit && limit < oldCount) {
                removing = true;
                beginRemoveRows(QModelIndex(), limit, oldCount - 1);
            }
        }

        m_limit = limit;

        if (inserting) {
            endInsertRows();
        } else if (removing) {
            endRemoveRows();
        }

        Q_EMIT limitChanged();
    }
}

void LimitProxyModel::sourceRowsAboutToBeInserted(const QModelIndex &parent, int start, int end)
{
    if (m_limit < 0) {
        beginInsertRows(mapFromSource(parent), start, end);
        m_sourceInserting = true;
    } else if (start < m_limit) {
        const int nSourceAddedItems = end - start + 1;
        const int currentCount = QIdentityProxyModel::rowCount();
        if (currentCount + nSourceAddedItems <= m_limit) {
            // After Inserting items we will be under the limit
            // so just proceed with the insertion normally
            beginInsertRows(mapFromSource(parent), start, end);
            m_sourceInserting = true;
        } else if (currentCount >= m_limit) {
            // We are already over the limit so to our users we are not adding items, just
            // changing it's data, i.e we had something like
            // A B C D E
            // with a limit of 5
            // after inserting (let's say three 'F' at position 1) we will have
            // A F F F B
            // so we just need to signal a dataChanged from 1 to 4
            m_dataChangedBegin = start;
            m_dataChangedEnd = m_limit - 1;
        } else { // currentCount < m_limit && currentCount + nSourceAddedItems > m_limit
            // We have less items than the limit but after adding them we will be over
            // To our users this means we need to insert some items and change the
            // data of some others, i.e we had something like
            // A B C
            // with a limit of 5
            // after inserting (let's say three 'F' at position 1) we will have
            // A F F F B
            // so we need to signal an insetion from position 1 to 2, instead of from
            // position 1 to 3 and a after that a data changed from 3 to 4
            const int nItemsToInsert = m_limit - currentCount;
            beginInsertRows(mapFromSource(parent), start, start + nItemsToInsert - 1);
            m_sourceInserting = true;
            m_dataChangedBegin = start + nItemsToInsert;
            m_dataChangedEnd = m_limit - 1;
            if (m_dataChangedBegin > m_dataChangedEnd) {
                // Just in case we were empty and insert 6 items with a limit of 5
                // We don't want to signal a dataChanged from 5 to 4
                m_dataChangedBegin = -1;
                m_dataChangedEnd = -1;
            }
        }
    }
}

void LimitProxyModel::sourceRowsAboutToBeRemoved(const QModelIndex &parent, int start, int end)
{
    if (m_limit < 0) {
        beginRemoveRows(mapFromSource(parent), start, end);
        m_sourceRemoving = true;
    } else if (start < m_limit) {
        const int nSourceRemovedItems = end - start + 1;
        const int currentCount = QIdentityProxyModel::rowCount();
        if (currentCount <= m_limit) {
            // We are already under the limit so
            // so just proceed with the removal normally
            beginRemoveRows(mapFromSource(parent), start, end);
            m_sourceRemoving = true;
        } else if (currentCount - nSourceRemovedItems >= m_limit) {
            // Even after removing items we will be at or over the limit
            // So to our users we are not removing anything, just changing the data
            // i.e. we had a internal model with
            // A B C D E F G H
            // and a limit of 5, our users just see
            // A B C D E
            // so if we remove 3 items starting at 1 we have to expose
            // A E F G H
            // that is, a dataChanged from 1 to 4
            m_dataChangedBegin = start;
            m_dataChangedEnd = m_limit - 1;
        } else { // currentCount > m_limit && currentCount - nSourceRemovedItems < m_limit
            // We have more items than the limit but after removing we will be below it
            // So to our users we both removing and changing the data
            // i.e. we had a internal model with
            // A B C D E F G
            // and a limit of 5, our users just see
            // A B C D E
            // so if we remove items from 1 to 3 we have to expose
            // A E F G
            // that is, a remove from 4 to 4 and a dataChanged from 1 to 3
            const int nItemsToRemove = m_limit - (currentCount - nSourceRemovedItems);
            beginRemoveRows(mapFromSource(parent), m_limit - nItemsToRemove, m_limit - 1);
            m_sourceRemoving = true;
            m_dataChangedBegin = start;
            m_dataChangedEnd = m_limit - nItemsToRemove - 1;
            if (m_dataChangedBegin > m_dataChangedEnd) {
                m_dataChangedBegin = -1;
                m_dataChangedEnd = -1;
            }
        }
    }
}

void LimitProxyModel::sourceRowsInserted(const QModelIndex & /*parent*/, int /*start*/, int /*end*/)
{
    if (m_sourceInserting) {
        endInsertRows();
        m_sourceInserting = false;
    }
    if (m_dataChangedBegin != -1 && m_dataChangedEnd != -1) {
        dataChanged(index(m_dataChangedBegin, 0), index(m_dataChangedEnd, 0));
        m_dataChangedBegin = -1;
        m_dataChangedEnd = -1;
    }
}

void LimitProxyModel::sourceRowsRemoved(const QModelIndex & /*parent*/, int /*start*/, int /*end*/)
{
    if (m_sourceRemoving) {
        endRemoveRows();
        m_sourceRemoving = false;
    }
    if (m_dataChangedBegin != -1 && m_dataChangedEnd != -1) {
        dataChanged(index(m_dataChangedBegin, 0), index(m_dataChangedEnd, 0));
        m_dataChangedBegin = -1;
        m_dataChangedEnd = -1;
    }
}

QVariantMap LimitProxyModel::get(int i) const
{
    QVariantMap item;
    QHash<int, QByteArray> roles = roleNames();

    QModelIndex modelIndex = index(i, 0);
    if (modelIndex.isValid()) {
        Q_FOREACH(int role, roles.keys()) {
            QString roleName = QString::fromUtf8(roles.value(role));
            item.insert(roleName, data(modelIndex, role));
        }
    }
    return item;
}

