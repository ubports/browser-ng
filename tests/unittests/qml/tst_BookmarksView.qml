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
import QtQuick.Window 2.2
import QtTest 1.0
import "../../../src/app/webbrowser"
import webbrowserapp.private 0.1

FocusScope {
    id: root

    focus: true
    width: 300
    height: 500

    BookmarksView {
        id: view
        anchors.fill: parent
        focus: true
        homepageUrl: "http://example.com/homepage"
    }

    SignalSpy {
        id: bookmarkEntryClickedSpy
        target: view
        signalName: "bookmarkEntryClicked"
    }

    WebbrowserTestCase {
        name: "BookmarksView"
        when: windowShown

        function init() {
            BookmarksModel.databasePath = ":memory:"
            populate()
            verify(view.activeFocus)
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
            var items = getListItems(findChild(view, "bookmarksFolderListView"),
                                     "bookmarkFolderDelegateLoader")

            clickItem(findChild(items[0], "urlDelegate_0"))
            compare(bookmarkEntryClickedSpy.count, 1)
            compare(bookmarkEntryClickedSpy.signalArguments[0][0], view.homepageUrl)

            clickItem(findChild(items[0], "urlDelegate_1"))
            compare(bookmarkEntryClickedSpy.count, 2)
            compare(bookmarkEntryClickedSpy.signalArguments[1][0], "http://example.com")
        }

        function test_delete_bookmark() {
            var items = getListItems(findChild(view, "bookmarksFolderListView"),
                                     "bookmarkFolderDelegateLoader")
            var bookmark = findChild(items[0], "urlDelegate_1")
            swipeToDeleteAndConfirm(bookmark)
            tryCompare(BookmarksModel, "count", 2)
        }

        function test_keyboard_navigation() {
            var listview = findChild(view, "bookmarksFolderListView")
            waitForRendering(listview)
            verify(listview.activeFocus)

            var firstHeader = findChild(listview, "bookmarkFolderHeader")
            verify(firstHeader.activeFocus)
            var firstFolder = firstHeader.parent
            compare(firstFolder.folderName, "")
            verify(firstFolder.expanded)

            keyClick(Qt.Key_Up)
            verify(firstHeader.activeFocus)

            keyClick(Qt.Key_Space)
            verify(!firstFolder.expanded)

            keyClick(Qt.Key_Space)
            verify(firstFolder.expanded)

            keyClick(Qt.Key_Up)
            verify(firstHeader.activeFocus)

            keyClick(Qt.Key_Down)
            verify(findChild(firstFolder, "urlDelegate_0").activeFocus)

            keyClick(Qt.Key_Enter)
            compare(bookmarkEntryClickedSpy.count, 1)
            compare(bookmarkEntryClickedSpy.signalArguments[0][0], "http://example.com/homepage")

            keyClick(Qt.Key_Down)
            verify(findChild(firstFolder, "urlDelegate_1").activeFocus)

            keyClick(Qt.Key_Return)
            compare(bookmarkEntryClickedSpy.count, 2)
            compare(bookmarkEntryClickedSpy.signalArguments[1][0], "http://example.com")

            keyClick(Qt.Key_Delete)
            compare(BookmarksModel.count, 2)
            verify(findChild(firstFolder, "urlDelegate_0").activeFocus)

            keyClick(Qt.Key_Down)
            var secondHeader = root.Window.activeFocusItem
            compare(secondHeader.objectName, "bookmarkFolderHeader")
            var secondFolder = secondHeader.parent
            compare(secondFolder.folderName, "FolderA")
            verify(!secondFolder.expanded)

            keyClick(Qt.Key_Down)
            var thirdHeader = root.Window.activeFocusItem
            compare(thirdHeader.objectName, "bookmarkFolderHeader")
            var thirdFolder = thirdHeader.parent
            compare(thirdFolder.folderName, "FolderB")
            verify(!thirdFolder.expanded)

            keyClick(Qt.Key_Down)
            verify(thirdHeader.activeFocus)

            keyClick(Qt.Key_Delete)
            verify(thirdHeader.activeFocus)

            keyClick(Qt.Key_Space)
            verify(thirdFolder.expanded)

            keyClick(Qt.Key_Down)
            verify(findChild(thirdFolder, "urlDelegate_0").activeFocus)

            keyClick(Qt.Key_Delete)
            compare(BookmarksModel.count, 1)
            verify(!thirdFolder.active)
            verify(secondFolder.activeFocus)

            keyClick(Qt.Key_Space)
            verify(secondFolder.expanded)
        }
    }
}
