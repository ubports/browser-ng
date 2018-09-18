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

#include "history-lastvisitdatelist-model.h"
#include "history-model.h"

// Qt
#include <QtCore/QDebug>
#include <QtCore/QStringList>

/*!
    \class HistoryLastVisitDateListModel
    \brief List model that exposes a list of all last visit dates from history

    HistoryLastVisitDateListModel is a list model that exposes all last visit
    dates from the source model. Each item has one single role: 'lastVisitDate'
    for a date in which there is at least one url visited on the source model.
    A special entry is added to the beginning of the list to represent all dates.

    The source model needs to expose a role named 'lastVisitDate', from which
    the input dates will be read. If such role is not present, this model will
    not expose any dates.
*/
HistoryLastVisitDateListModel::HistoryLastVisitDateListModel(QObject* parent)
    : QAbstractListModel(parent)
    , m_sourceModel(0)
{
}

HistoryLastVisitDateListModel::~HistoryLastVisitDateListModel()
{
    clearLastVisitDates();
}

QHash<int, QByteArray> HistoryLastVisitDateListModel::roleNames() const
{
    static QHash<int, QByteArray> roles;
    if (roles.isEmpty()) {
        roles[LastVisitDate] = "lastVisitDate";
    }
    return roles;
}

int HistoryLastVisitDateListModel::rowCount(const QModelIndex& parent) const
{
    Q_UNUSED(parent);
    return m_orderedDates.count();
}

QVariant HistoryLastVisitDateListModel::data(const QModelIndex& index, int role) const
{
    if (!index.isValid()) {
        return QVariant();
    }
    const QDate lastVisitDate = m_orderedDates.at(index.row());

    switch (role) {
    case LastVisitDate:
        return lastVisitDate;
    default:
        return QVariant();
    }
}

QVariant HistoryLastVisitDateListModel::sourceModel() const
{
    return (m_sourceModel) ? QVariant::fromValue(m_sourceModel) : QVariant();
}

void HistoryLastVisitDateListModel::setSourceModel(QVariant sourceModel)
{
    QAbstractItemModel* newSourceModel = qvariant_cast<QAbstractItemModel*>(sourceModel);
    if (sourceModel.isValid() && (newSourceModel == 0) && !sourceModel.canConvert<void*>()) {
        qWarning() << "Only QAbstractItemModel-derived instances and null are"
                   << "allowed as source models";
    }

    if (newSourceModel != m_sourceModel) {
        beginResetModel();
        if (m_sourceModel != 0) {
            m_sourceModel->disconnect(this);
        }
        clearLastVisitDates();

        m_sourceModel = newSourceModel;
        updateSourceModelRole();

        populateModel();
        if (m_sourceModel != 0) {
            connect(m_sourceModel, SIGNAL(rowsInserted(const QModelIndex&, int, int)),
                    SLOT(onRowsInserted(const QModelIndex&, int, int)));
            connect(m_sourceModel, SIGNAL(rowsRemoved(const QModelIndex&, int, int)),
                    SLOT(onRowsRemoved(const QModelIndex&, int, int)));
            connect(m_sourceModel,
                    SIGNAL(rowsMoved(const QModelIndex&, int, int, const QModelIndex&, int)),
                    SLOT(onRowsMoved(const QModelIndex&, int, int, const QModelIndex&, int)));
            connect(m_sourceModel, SIGNAL(modelReset()), SLOT(onModelReset()));
            connect(m_sourceModel, SIGNAL(layoutChanged(QList<QPersistentModelIndex>, QAbstractItemModel::LayoutChangeHint)),
                    SLOT(onModelReset()));
        }
        endResetModel();
        Q_EMIT sourceModelChanged();
    }
}

void HistoryLastVisitDateListModel::clearLastVisitDates()
{
    m_orderedDates.clear();
    Q_FOREACH(const QDate& lastVisitDate, m_lastVisitDates.keys()) {
        delete m_lastVisitDates.take(lastVisitDate);
    }
}

void HistoryLastVisitDateListModel::populateModel()
{
    if (m_sourceModel != 0) {
        int count = m_sourceModel->rowCount();
        for (int i = 0; i < count; ++i) {
            insertNewHistoryEntry(new QPersistentModelIndex(m_sourceModel->index(i, 0)), false);
        }
    }
}

void HistoryLastVisitDateListModel::onRowsInserted(const QModelIndex& parent, int start, int end)
{
    for (int i = start; i <= end; ++i) {
        insertNewHistoryEntry(new QPersistentModelIndex(m_sourceModel->index(i, 0)), true);
    }
}

void HistoryLastVisitDateListModel::onRowsRemoved(const QModelIndex& parent, int start, int end)
{
    QMap<QDate, QList<QPersistentModelIndex*>*>::iterator lastVisitDate = m_lastVisitDates.begin();
    while (lastVisitDate != m_lastVisitDates.end()) {

        QList<QPersistentModelIndex*>::iterator entry = lastVisitDate.value()->begin();
        while (entry != lastVisitDate.value()->end()) {
            QPersistentModelIndex *index = *entry;
            if (!index->isValid()) {
                entry = lastVisitDate.value()->erase(entry);
            } else {
                ++entry;
            }
        }

        if (lastVisitDate.value()->isEmpty()) {
            int removeAt = m_orderedDates.indexOf(lastVisitDate.key());
            beginRemoveRows(QModelIndex(), removeAt, removeAt);
            m_orderedDates.removeAt(removeAt);
            delete lastVisitDate.value();
            lastVisitDate = m_lastVisitDates.erase(lastVisitDate);
            endRemoveRows();
        } else {
            ++lastVisitDate;
        }
    }

    if (m_lastVisitDates.isEmpty()) {
        // Remove the default entry if model is empty
        beginRemoveRows(QModelIndex(), 0, 0);
        m_orderedDates.clear();
        endRemoveRows();
    }
}

void HistoryLastVisitDateListModel::onRowsMoved(const QModelIndex& parent, int start, int end, const QModelIndex& destination, int row)
{
    Q_UNUSED(parent);
    Q_UNUSED(destination);

    // Rows were moved in the source model, meaning that their last visit dates
    // were potentially updated, so we remove all the dates corresponding to
    // the rows before they were moved, and we add all the dates corresponding
    // to the rows after they were moved.

    // Determine a lower and upper bound for the dates that should be removed
    // by looking at the indexes surrounding the rows before they were moved.
    QDate lower = m_sourceModel->data(m_sourceModel->index((row < start) ? end + 1 : start, 0), m_sourceModelRole).toDate();
    if (!lower.isValid()) {
        // The last row was moved too, we don’t have a strict lower bound.
        lower = m_orderedDates.last().addDays(-1);
    }
    QDate upper = m_sourceModel->data(m_sourceModel->index((row < start) ? end : start - 1, 0), m_sourceModelRole).toDate();
    for (QDate i = upper.addDays(-1); i > lower; i = i.addDays(-1)) {
        if (m_orderedDates.contains(i)) {
            int removeAt = m_orderedDates.indexOf(i);
            beginRemoveRows(QModelIndex(), removeAt, removeAt);
            m_orderedDates.removeAt(removeAt);
            delete m_lastVisitDates.take(i);
            endRemoveRows();
        }
    }

    // Now add back dates for all the rows after they were moved.
    for (int i = 0; i <= (end - start); ++i) {
        int index = i + row + ((row < start) ? 0 : start - end);
        insertNewHistoryEntry(new QPersistentModelIndex(m_sourceModel->index(index, 0)), true);
    }
}

void HistoryLastVisitDateListModel::updateSourceModelRole()
{
  if (m_sourceModel && m_sourceModel->roleNames().count() > 0) {
    m_sourceModelRole = m_sourceModel->roleNames().key("lastVisitDate", -1);
    if (m_sourceModelRole == -1) {
        qWarning() << "No results will be returned because the sourceModel"
                   << "does not have a role named \"lastVisitDate\"";
    }
  }
}

void HistoryLastVisitDateListModel::onModelReset()
{
    beginResetModel();
    updateSourceModelRole();
    clearLastVisitDates();
    populateModel();
    endResetModel();
}

void HistoryLastVisitDateListModel::insertNewHistoryEntry(QPersistentModelIndex* index, bool notify)
{
    if (m_sourceModelRole == -1) {
        return;
    }

    QDate lastVisitDate = index->data(m_sourceModelRole).toDate();
    if (!m_lastVisitDates.contains(lastVisitDate)) {
        if (m_orderedDates.isEmpty()) {
            // Add default entry to represent all dates
            if (notify) {
                beginInsertRows(QModelIndex(), 0, 0);
            }
            m_orderedDates.append(QDate());
            if (notify) {
                endInsertRows();
            }
        }

        int insertAt = 1;
        QList<QPersistentModelIndex*> *entries = new QList<QPersistentModelIndex*>();
        while (insertAt < m_orderedDates.count()) {
            if (lastVisitDate > m_orderedDates.at(insertAt)) {
                break;
            }
            ++insertAt;
        }

        if (notify) {
            beginInsertRows(QModelIndex(), insertAt, insertAt);
        }

        m_orderedDates.insert(insertAt, lastVisitDate);
        m_lastVisitDates.insert(lastVisitDate, entries);

        if (notify) {
            endInsertRows();
        }
    }

    m_lastVisitDates[lastVisitDate]->append(index);
}
