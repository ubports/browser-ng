/*
 * Copyright 2013-2017 Canonical Ltd.
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
#include <QtCore/QFile>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTemporaryDir>
#include <QtQml/QQmlEngine>
#include <QtQml/QtQml>
#include <QtQuickTest/QtQuickTest>

// local
#include "bookmarks-model.h"
#include "bookmarks-folderlist-model.h"
#include "favicon-fetcher.h"
#include "file-operations.h"
#include "history-domain-model.h"
#include "history-domainlist-model.h"
#include "history-model.h"
#include "history-lastvisitdatelist-model.h"
#include "limit-proxy-model.h"
#include "reparenter.h"
#include "searchengine.h"
#include "tabs-model.h"
#include "text-search-filter-model.h"

class TestContext : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString testDir1 READ testDir1 CONSTANT)
    Q_PROPERTY(QString testDir2 READ testDir2 CONSTANT)

public:
    explicit TestContext(QObject* parent=0)
        : QObject(parent)
    {}

    QString testDir1() const
    {
        return m_testDir1.path();
    }

    QString testDir2() const
    {
        return m_testDir2.path();
    }

    Q_INVOKABLE bool writeSearchEngineDescription(
        const QString& path, const QString& filename, const QString& name,
        const QString& description, const QString& urlTemplate)
    {
        QFile file(QDir(path).absoluteFilePath(QString("%1.xml").arg(filename)));
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << "<OpenSearchDescription xmlns=\"http://a9.com/-/spec/opensearch/1.1/\">";
            out << "<ShortName>" << name << "</ShortName>";
            out << "<Description>" << description << "</Description>";
            out << "<Url type=\"text/html\" template=\"" << urlTemplate << "\"/>";
            out << "</OpenSearchDescription>";
            file.close();
            return true;
        } else {
            return false;
        }
    }

    Q_INVOKABLE bool writeInvalidSearchEngineDescription(const QString& path, const QString& filename)
    {
        QFile file(QDir(path).absoluteFilePath(QString("%1.xml").arg(filename)));
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << "invalid";
            file.close();
            return true;
        } else {
            return false;
        }
    }

    Q_INVOKABLE bool deleteSearchEngineDescription(const QString& path, const QString& filename)
    {
        return QFile(QDir(path).absoluteFilePath(QString("%1.xml").arg(filename))).remove();
    }

    Q_INVOKABLE bool createFile(const QString& filePath) {
        // create all the directories necessary for the file to be created
        QFileInfo fileInfo(filePath);
        if (!QFileInfo::exists(fileInfo.path())) {
          QDir::root().mkpath(fileInfo.path());
        }

        QFile file(fileInfo.absoluteFilePath());
        return file.open(QIODevice::WriteOnly | QIODevice::Text);
    }

    Q_INVOKABLE bool removeDirectory(const QString& path) {
        QDir dir(path);
        return dir.removeRecursively();
    }

private:
    QTemporaryDir m_testDir1;
    QTemporaryDir m_testDir2;
};

class HistoryModelMock : public HistoryModel {
    Q_OBJECT

public:
    static bool compareHistoryEntries(const HistoryEntry& a, const HistoryEntry& b) {
        return a.lastVisit < b.lastVisit;
    }

    Q_INVOKABLE int addByDate(const QUrl& url, const QString& title, const QDateTime& date)
    {
        int index = getEntryIndex(url);
        int visitsToAdd = 1;
        if (index == -1) {
            add(url, title, QString());
            index = getEntryIndex(url);
            visitsToAdd = 0;
        }

        // Since this is useful only for testing and efficiency is not critical
        // we reorder the model and reset it every time we add a new item by date
        // to keep things simple.
        beginResetModel();
        HistoryEntry entry = m_entries.takeAt(index);
        entry.lastVisit = date;
        entry.visits = entry.visits + visitsToAdd;
        m_entries.append(entry);
        std::sort(m_entries.begin(), m_entries.end(), compareHistoryEntries);
        endResetModel();

        updateExistingEntryInDatabase(entry);

        return entry.visits;
    }
};

#define MAKE_SINGLETON_FACTORY(type) \
    static QObject* type##_singleton_factory(QQmlEngine* engine, QJSEngine* scriptEngine) { \
        Q_UNUSED(engine); \
        Q_UNUSED(scriptEngine); \
        return new type(); \
    }

MAKE_SINGLETON_FACTORY(FileOperations)
MAKE_SINGLETON_FACTORY(BookmarksModel)
MAKE_SINGLETON_FACTORY(HistoryModelMock)
MAKE_SINGLETON_FACTORY(TestContext)
MAKE_SINGLETON_FACTORY(Reparenter)

int main(int argc, char** argv)
{
    const char* commonUri = "webbrowsercommon.private";
    qmlRegisterType<FaviconFetcher>(commonUri, 0, 1, "FaviconFetcher");
    qmlRegisterSingletonType<FileOperations>(commonUri, 0, 1, "FileOperations", FileOperations_singleton_factory);

    const char* browserUri = "webbrowserapp.private";
    qmlRegisterType<SearchEngine>(browserUri, 0, 1, "SearchEngine");
    qmlRegisterType<TabsModel>(browserUri, 0, 1, "TabsModel");
    qmlRegisterSingletonType<BookmarksModel>(browserUri, 0, 1, "BookmarksModel", BookmarksModel_singleton_factory);
    qmlRegisterType<BookmarksFolderListModel>(browserUri, 0, 1, "BookmarksFolderListModel");
    qmlRegisterSingletonType<HistoryModel>(browserUri, 0, 1, "HistoryModel", HistoryModelMock_singleton_factory);
    qmlRegisterType<HistoryDomainModel>(browserUri, 0, 1, "HistoryDomainModel");
    qmlRegisterType<HistoryDomainListModel>(browserUri, 0, 1, "HistoryDomainListModel");
    qmlRegisterType<HistoryLastVisitDateListModel>(browserUri, 0, 1, "HistoryLastVisitDateListModel");
    qmlRegisterType<LimitProxyModel>(browserUri, 0, 1, "LimitProxyModel");
    qmlRegisterType<TextSearchFilterModel>(browserUri, 0, 1, "TextSearchFilterModel");
    qmlRegisterSingletonType<Reparenter>(browserUri, 0, 1, "Reparenter", Reparenter_singleton_factory);

    const char* testUri = "webbrowsertest.private";
    qmlRegisterSingletonType<TestContext>(testUri, 0, 1, "TestContext", TestContext_singleton_factory);

    return quick_test_main(argc, argv, "QmlTests", nullptr);
}

#include "tst_QmlTests.moc"
