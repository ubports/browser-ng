/*
 * Copyright 2015-2016 Canonical Ltd.
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

import QtQuick 2.4
import QtTest 1.0
import "../../../src/app/webbrowser"
import webbrowserapp.private 0.1

Item {
    id: root

    width: 800
    height: 600

    BookmarksViewWide {
        id: view
        anchors.fill: parent
        homepageUrl: "http://example.com/homepage"
    }

    SignalSpy {
        id: bookmarkEntryClickedSpy
        target: view
        signalName: "bookmarkEntryClicked"
    }

    WebbrowserTestCase {
        name: "BookmarksViewWide"
        when: windowShown

        function init() {
            BookmarksModel.databasePath = ":memory:"
            populate()
            view.forceActiveFocus()
            compare(bookmarkEntryClickedSpy.count, 0)
        }

        function populate() {
            BookmarksModel.add("http://example.com", "Example", "", "")
            BookmarksModel.add("http://example.org/a", "Example a", "", "FolderA")
            BookmarksModel.add("http://example.org/b", "Example b", "", "FolderB")
            compare(BookmarksModel.count, 3)
        }

        function cleanup() {
            BookmarksModel.databasePath = ""
            bookmarkEntryClickedSpy.clear()
        }

        function test_click_bookmark() {
            var items = getListItems(findChild(view, "bookmarksList"), "bookmarkItem")

            clickItem(items[0])
            compare(bookmarkEntryClickedSpy.count, 1)
            compare(bookmarkEntryClickedSpy.signalArguments[0][0], view.homepageUrl)

            clickItem(items[1])
            compare(bookmarkEntryClickedSpy.count, 2)
            compare(bookmarkEntryClickedSpy.signalArguments[1][0], "http://example.com")
        }

        function test_delete_bookmark() {
            var bookmark = getListItems(findChild(view, "bookmarksList"), "bookmarkItem")[1]
            swipeToDeleteAndConfirm(bookmark)
            tryCompare(BookmarksModel, "count", 2)
        }
    }
}
