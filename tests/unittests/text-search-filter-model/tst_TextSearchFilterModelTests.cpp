/*
 * Copyright 2013-2015 Canonical Ltd.
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
#include <QtTest/QSignalSpy>
#include <QtTest/QtTest>

// local
#include "bookmarks-model.h"
#include "text-search-filter-model.h"

class TextSearchFilterModelTests : public QObject
{
    Q_OBJECT

private:
    BookmarksModel* model;
    TextSearchFilterModel* matches;

private Q_SLOTS:
    void init()
    {
        model = new BookmarksModel;
        model->setDatabasePath(":memory:");
        matches = new TextSearchFilterModel;
        matches->setSourceModel(QVariant::fromValue(model));
    }

    void cleanup()
    {
        delete matches;
        delete model;
    }

    void shouldBeInitiallyEmpty()
    {
        QCOMPARE(matches->rowCount(), 0);
    }

    void shouldNotifyWhenChangingSourceModel()
    {
        QSignalSpy spy(matches, SIGNAL(sourceModelChanged()));
        matches->setSourceModel(QVariant::fromValue(model));
        QVERIFY(spy.isEmpty());
        BookmarksModel* model2 = new BookmarksModel;
        model2->setDatabasePath(":memory:");
        matches->setSourceModel(QVariant::fromValue(model2));
        QCOMPARE(spy.count(), 1);
        QCOMPARE(matches->sourceModel(), QVariant::fromValue(model2));
        matches->setSourceModel(QVariant());
        QCOMPARE(spy.count(), 2);
        QVERIFY(matches->sourceModel().isNull());
        delete model2;
    }

    void shouldReturnAllWhileTermsAndOrFieldsEmpty()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        QCOMPARE(matches->rowCount(), 2);
        matches->setTerms(QStringList({"org"}));
        QCOMPARE(matches->rowCount(), 2);
        matches->setSearchFields(QStringList({"url"}));
        QCOMPARE(matches->rowCount(), 1);
        matches->setTerms(QStringList());
        QCOMPARE(matches->rowCount(), 2);
    }

    void shouldRecordTerms()
    {
        QVERIFY(matches->terms().isEmpty());
        QStringList terms;
        terms.append("example");
        matches->setTerms(terms);
        QCOMPARE(matches->terms(), terms);
    }

    void shouldRecordSearchFields()
    {
        QVERIFY(matches->searchFields().isEmpty());
        QStringList fields;
        fields.append("url");
        matches->setSearchFields(fields);
        QCOMPARE(matches->searchFields(), fields);
    }

    void shouldMatch()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        matches->setTerms(QStringList({"example"}));
        matches->setSearchFields(QStringList({"url", "title"}));
        QCOMPARE(matches->rowCount(), 2);
    }

    void shouldMatchSecondField()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        matches->setTerms(QStringList({"domain"}));
        matches->setSearchFields(QStringList({"url", "title"}));
        QCOMPARE(matches->rowCount(), 2);
    }

    void shouldFilterOutNotMatchingEntries()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://ubuntu.com"), "Home | Ubuntu", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://wikipedia.org"), "Wikipedia", QUrl(), "");
        matches->setTerms(QStringList({"domain"}));
        matches->setSearchFields(QStringList({"url", "title"}));
        QCOMPARE(matches->rowCount(), 2);
    }

    void shouldUpdateResultsWhenTermsChange()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://ubuntu.com"), "Home | Ubuntu", QUrl(), "");
        model->add(QUrl("http://wikipedia.org"), "Wikipedia", QUrl(), "");
        model->add(QUrl("http://ubuntu.com/download"), "Download Ubuntu | Ubuntu", QUrl(), "");
        matches->setSearchFields(QStringList({"url", "title"}));
        matches->setTerms(QStringList({"ubuntu"}));
        QCOMPARE(matches->rowCount(), 2);
        matches->setTerms(QStringList({"wiki"}));
        QCOMPARE(matches->rowCount(), 1);
    }

    void shouldUpdateResultsWhenSourceModelUpdates()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://wikipedia.org"), "Wikipedia", QUrl(), "");
        matches->setTerms(QStringList({"ubuntu"}));
        matches->setSearchFields(QStringList({"url"}));
        QCOMPARE(matches->rowCount(), 0);
        model->add(QUrl("http://ubuntu.com"), "Home | Ubuntu", QUrl(), "");
        QCOMPARE(matches->rowCount(), 1);
    }

    void shouldMatchAllTerms()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        matches->setTerms(QStringList({"example", "org"}));
        matches->setSearchFields(QStringList({"url", "title"}));
        QCOMPARE(matches->rowCount(), 1);
    }

    void shouldMatchTermsInDifferentFields()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        matches->setTerms(QStringList({"org", "domain"}));
        matches->setSearchFields(QStringList({"url", "title"}));
        QCOMPARE(matches->rowCount(), 1);
    }

    void shouldMatchDuplicateTerms()
    {
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        model->add(QUrl("http://example.com"), "Example Domain", QUrl(), "");
        matches->setTerms(QStringList({"org", "org", "org", "org"}));
        matches->setSearchFields(QStringList({"url", "title"}));
        QCOMPARE(matches->rowCount(), 1);
    }

    void shouldWarnOnInvalidFields()
    {
        QTest::ignoreMessage(QtWarningMsg, "Source model does not have role matching field: \"foo\"");
        model->add(QUrl("http://example.org"), "Example Domain", QUrl(), "");
        matches->setTerms(QStringList({"org"}));
        matches->setSearchFields(QStringList({"url", "foo"}));
        QCOMPARE(matches->count(), 1);
    }
};

QTEST_MAIN(TextSearchFilterModelTests)
#include "tst_TextSearchFilterModelTests.moc"
