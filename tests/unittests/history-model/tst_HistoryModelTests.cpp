/*
 * Copyright 2013-2016 Canonical Ltd.
 *
 * This file is part of webbrowser-app.
 *
 * webbrowser-app is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * webbrowser-app is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Qt
#include <QtCore/QDir>
#include <QtCore/QTemporaryFile>
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

// local
#include "history-model.h"

class HistoryModelTests : public QObject
{
    Q_OBJECT

private:
    HistoryModel* model;

private Q_SLOTS:
    void init()
    {
        model = new HistoryModel;
        model->setDatabasePath(":memory:");
    }

    void cleanup()
    {
        delete model;
    }

    void shouldBeInitiallyEmpty()
    {
        QCOMPARE(model->rowCount(), 0);
    }

    void shouldNotAddEmptyUrl()
    {
        QCOMPARE(model->add(QUrl(), "empty URL", QUrl()), 0);
        QCOMPARE(model->rowCount(), 0);
    }

    void shouldAddNewEntries()
    {
        QCOMPARE(model->add(QUrl("http://example.org/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 1);
        QCOMPARE(model->add(QUrl("http://example.com/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 2);
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Url).toString(),
                 QString("http://example.com/"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Visits).toInt(), 1);
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Hidden).toBool(), false);
        QCOMPARE(model->data(model->index(1, 0), HistoryModel::Url).toString(),
                 QString("http://example.org/"));
        QCOMPARE(model->data(model->index(1, 0), HistoryModel::Visits).toInt(), 1);
        QCOMPARE(model->data(model->index(1, 0), HistoryModel::Hidden).toBool(), false);
    }

    void shouldNotifyWhenAddingNewEntries()
    {
        QSignalSpy spy(model, SIGNAL(rowsInserted(const QModelIndex&, int, int)));
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        QCOMPARE(spy.count(), 1);
        QList<QVariant> args = spy.takeFirst();
        QCOMPARE(args.at(1).toInt(), 0);
        QCOMPARE(args.at(2).toInt(), 0);
        model->add(QUrl("http://example.com/"), "Example Domain", QUrl());
        QCOMPARE(spy.count(), 1);
        args = spy.takeFirst();
        QCOMPARE(args.at(1).toInt(), 0);
        QCOMPARE(args.at(2).toInt(), 0);
    }

    void shouldUpdateExistingEntry()
    {
        QCOMPARE(model->add(QUrl("http://example.org/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 1);
        QCOMPARE(model->add(QUrl("http://example.org/"), "Example Domain", QUrl("image://webicon/123")), 2);
        QCOMPARE(model->rowCount(), 1);
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Url).toString(),
                 QString("http://example.org/"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Visits).toInt(), 2);
    }

    void shouldNotifyWhenUpdatingExistingEntry()
    {
        QSignalSpy spyMoved(model, SIGNAL(rowsMoved(const QModelIndex&, int, int, const QModelIndex&, int)));
        qRegisterMetaType<QVector<int> >();
        QSignalSpy spyChanged(model, SIGNAL(dataChanged(const QModelIndex&, const QModelIndex&, const QVector<int>&)));
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        QCOMPARE(spyMoved.count(), 0);
        QCOMPARE(spyChanged.count(), 0);
        QTest::qWait(100);
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl("image://webicon/123"));
        QCOMPARE(spyMoved.count(), 0);
        QCOMPARE(spyChanged.count(), 1);
        QList<QVariant> args = spyChanged.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        QVector<int> roles = args.at(2).value<QVector<int> >();
        QVERIFY(roles.size() >= 2);
        QVERIFY(roles.contains(HistoryModel::Icon));
        QVERIFY(roles.contains(HistoryModel::Visits));
        model->add(QUrl("http://example.com/"), "Example Domain", QUrl());
        QCOMPARE(spyMoved.count(), 0);
        QCOMPARE(spyChanged.count(), 0);
        model->add(QUrl("http://example.org/"), "Example D0ma1n", QUrl("image://webicon/456"));
        QCOMPARE(spyMoved.count(), 1);
        args = spyMoved.takeFirst();
        QCOMPARE(args.at(1).toInt(), 1);
        QCOMPARE(args.at(2).toInt(), 1);
        QCOMPARE(args.at(4).toInt(), 0);
        QCOMPARE(spyChanged.count(), 1);
        args = spyChanged.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        roles = args.at(2).value<QVector<int> >();
        QVERIFY(roles.size() >= 3);
        QVERIFY(roles.contains(HistoryModel::Title));
        QVERIFY(roles.contains(HistoryModel::Icon));
        QVERIFY(roles.contains(HistoryModel::Visits));
    }

    void shouldUpdateAttributes()
    {
        qRegisterMetaType<QVector<int> >();
        QSignalSpy spyChanged(model, SIGNAL(dataChanged(const QModelIndex&, const QModelIndex&, const QVector<int>&)));
        QUrl url(QStringLiteral("http://example.org/"));
        QCOMPARE(model->add(url, QStringLiteral(""), QUrl()), 1);

        QVERIFY(!model->update(QUrl(), QStringLiteral(""), QUrl()));
        QVERIFY(spyChanged.isEmpty());

        QVERIFY(!model->update(QUrl(QStringLiteral("http://example.com/")), QStringLiteral(""), QUrl()));
        QVERIFY(spyChanged.isEmpty());

        QVERIFY(!model->update(url, QStringLiteral(""), QUrl()));
        QVERIFY(spyChanged.isEmpty());

        QVERIFY(model->update(url, QStringLiteral("title update"), QUrl()));
        QCOMPARE(spyChanged.count(), 1);
        QList<QVariant> args = spyChanged.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        QVector<int> roles = args.at(2).value<QVector<int> >();
        QCOMPARE(roles.size(), 1);
        QVERIFY(roles.contains(HistoryModel::Title));
        QCOMPARE(model->get(0)[QStringLiteral("visits")].toInt(), 1);

        QVERIFY(model->update(url, QStringLiteral("title update"), QUrl(QStringLiteral("image://webicon/123"))));
        QCOMPARE(spyChanged.count(), 1);
        args = spyChanged.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        roles = args.at(2).value<QVector<int> >();
        QCOMPARE(roles.size(), 1);
        QVERIFY(roles.contains(HistoryModel::Icon));
        QCOMPARE(model->get(0)[QStringLiteral("visits")].toInt(), 1);

        QVERIFY(model->update(url, QStringLiteral("title update 2"), QUrl(QStringLiteral("image://webicon/1234"))));
        QCOMPARE(spyChanged.count(), 1);
        args = spyChanged.takeFirst();
        QCOMPARE(args.at(0).toModelIndex().row(), 0);
        QCOMPARE(args.at(1).toModelIndex().row(), 0);
        roles = args.at(2).value<QVector<int> >();
        QCOMPARE(roles.size(), 2);
        QVERIFY(roles.contains(HistoryModel::Title));
        QVERIFY(roles.contains(HistoryModel::Icon));
        QCOMPARE(model->get(0)[QStringLiteral("visits")].toInt(), 1);
    }

    void shouldNotifyWhenHidingOrUnHidingExistingEntry()
    {
        qRegisterMetaType<QVector<int> >();
        QSignalSpy spyChanged(model, SIGNAL(dataChanged(const QModelIndex&, const QModelIndex&, const QVector<int>&)));
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Hidden).toBool(), false);
        model->hide(QUrl("http://example.org/"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Hidden).toBool(), true);
        QCOMPARE(spyChanged.count(), 1);
        QList<QVariant> args = spyChanged.takeFirst();
        QVector<int> roles = args.at(2).value<QVector<int> >();
        QVERIFY(roles.size() == 1);
        QVERIFY(roles.contains(HistoryModel::Hidden));
        model->unHide(QUrl("http://example.org/"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Hidden).toBool(), false);
        QCOMPARE(spyChanged.count(), 1);
        args = spyChanged.takeFirst();
        roles = args.at(2).value<QVector<int> >();
        QVERIFY(roles.size() == 1);
        QVERIFY(roles.contains(HistoryModel::Hidden));
    }

    void shouldUpdateTimestamp()
    {
        QDateTime now = QDateTime::currentDateTimeUtc();
        QTest::qWait(1001);
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        QTest::qWait(1001);
        model->add(QUrl("http://example.com/"), "Example Domain", QUrl());
        QDateTime ts0 = model->data(model->index(0, 0), HistoryModel::LastVisit).toDateTime();
        QDateTime ts1 = model->data(model->index(1, 0), HistoryModel::LastVisit).toDateTime();
        QVERIFY(ts0 > ts1);
        QVERIFY(ts1 > now);
    }

    void shouldReturnData()
    {
        QDateTime now = QDateTime::currentDateTimeUtc();
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl("image://webicon/123"));
        QVERIFY(!model->data(QModelIndex(), HistoryModel::Url).isValid());
        QVERIFY(!model->data(model->index(-1, 0), HistoryModel::Url).isValid());
        QVERIFY(!model->data(model->index(3, 0), HistoryModel::Url).isValid());
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Url).toUrl(), QUrl("http://example.org/"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Domain).toString(), QString("example.org"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Title).toString(), QString("Example Domain"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Icon).toUrl(), QUrl("image://webicon/123"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Visits).toInt(), 1);
        QVERIFY(model->data(model->index(0, 0), HistoryModel::LastVisit).toDateTime() >= now);
        QVERIFY(!model->data(model->index(0, 0), HistoryModel::LastVisit + 4).isValid());
    }

    void shouldReturnDatabasePath()
    {
        QCOMPARE(model->databasePath(), QString(":memory:"));
    }

    void shouldNotifyWhenSettingDatabasePath()
    {
        QSignalSpy spyPath(model, SIGNAL(databasePathChanged()));
        QSignalSpy spyReset(model, SIGNAL(modelReset()));

        model->setDatabasePath(":memory:");
        QVERIFY(spyPath.isEmpty());
        QVERIFY(spyReset.isEmpty());

        model->setDatabasePath("");
        QCOMPARE(spyPath.count(), 1);
        QCOMPARE(spyReset.count(), 1);
        QCOMPARE(model->databasePath(), QString(""));
    }

    void shouldSerializeOnDisk()
    {
        QTemporaryFile tempFile;
        tempFile.open();
        QString fileName = tempFile.fileName();
        delete model;
        model = new HistoryModel;
        model->setDatabasePath(fileName);
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        QTest::qWait(1001);
        model->add(QUrl("http://example.com/"), "Example Domain", QUrl());
        model->hide(QUrl("http://example.com/"));
        QTest::qWait(100);
        delete model;
        model = new HistoryModel;
        model->setDatabasePath(fileName);
        QTest::qWait(200);
        QTRY_COMPARE(model->rowCount(), 2);
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Url).toUrl(), QUrl("http://example.com/"));
        QCOMPARE(model->data(model->index(0, 0), HistoryModel::Hidden).toBool(), true);
        QCOMPARE(model->data(model->index(1, 0), HistoryModel::Url).toUrl(), QUrl("http://example.org/"));
        QCOMPARE(model->data(model->index(1, 0), HistoryModel::Hidden).toBool(), false);
    }

    void shouldClearAll()
    {
        QSignalSpy spyReset(model, SIGNAL(modelReset()));
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        model->add(QUrl("http://example.com/"), "Example Domain", QUrl());
        QCOMPARE(model->rowCount(), 2);
        QVERIFY(spyReset.isEmpty());
        model->clearAll();
        QCOMPARE(spyReset.count(), 1);
        QCOMPARE(model->rowCount(), 0);
        model->clearAll();
        QCOMPARE(spyReset.count(), 1);
    }

    void shouldRemoveByUrl()
    {
        QCOMPARE(model->add(QUrl("http://example.org/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 1);
        QCOMPARE(model->add(QUrl("http://example.com/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 2);

        model->removeEntryByUrl(QUrl("http://example.org/"));
        QCOMPARE(model->rowCount(), 1);
        model->removeEntryByUrl(QUrl("http://example.com/"));
        QCOMPARE(model->rowCount(), 0);
    }

    void shouldRemoveByDate()
    {
        QCOMPARE(model->add(QUrl("http://example.org/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 1);
        QCOMPARE(model->add(QUrl("http://example.com/"), "Example Domain", QUrl()), 1);
        QCOMPARE(model->rowCount(), 2);

        model->removeEntriesByDate(QDate::currentDate());
        QCOMPARE(model->rowCount(), 0);
    }

    void shouldRemoveByDomain()
    {
        QCOMPARE(model->add(QUrl("http://example.org/page1"), "Example Domain Page 1", QUrl()), 1);
        QCOMPARE(model->rowCount(), 1);
        QCOMPARE(model->add(QUrl("http://example.org/page2"), "Example Domain Page 2", QUrl()), 1);
        QCOMPARE(model->rowCount(), 2);
        QCOMPARE(model->add(QUrl("http://example.com/page1"), "Example Domain Page 1", QUrl()), 1);
        QCOMPARE(model->rowCount(), 3);
        QCOMPARE(model->add(QUrl("http://example.com/page2"), "Example Domain Page 2", QUrl()), 1);
        QCOMPARE(model->rowCount(), 4);

        model->removeEntriesByDomain("example.org");
        QCOMPARE(model->rowCount(), 2);
        model->removeEntriesByDomain("example.com");
        QCOMPARE(model->rowCount(), 0);
    }

    void shouldCountNumberOfEntries()
    {
        QSignalSpy spyCount(model, SIGNAL(rowCountChanged()));
        QCOMPARE(model->property("count").toInt(), 0);
        model->add(QUrl("http://example.org/"), "Example Domain", QUrl());
        QCOMPARE(model->property("count").toInt(), 1);
        QCOMPARE(spyCount.count(), 1);
        model->add(QUrl("http://example.com/"), "Example Domain", QUrl());
        QCOMPARE(model->property("count").toInt(), 2);
        QCOMPARE(spyCount.count(), 2);
        model->clearAll();
        QCOMPARE(model->property("count").toInt(), 0);
        QCOMPARE(spyCount.count(), 3);
    }

};

QTEST_MAIN(HistoryModelTests)
#include "tst_HistoryModelTests.moc"
