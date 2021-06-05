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

    property NewTabViewWide view
    property var bookmarks
    property string homepage: "http://example.com/homepage"

    Component {
        id: viewComponent
        NewTabViewWide {
            anchors.fill: parent
            settingsObject: QtObject {
                property url homepage: root.homepage
                property int newTabDefaultSection: 0
            }
        }
    }

    SignalSpy {
        id: historyEntryClickedSpy
        signalName: "historyEntryClicked"
    }

    SignalSpy {
        id: bookmarkClickedSpy
        signalName: "bookmarkClicked"
    }

    SignalSpy {
        id: bookmarkRemovedSpy
        signalName: "bookmarkRemoved"
    }

    WebbrowserTestCase {
        name: "NewTabViewWide"
        when: windowShown

        function init()
        {
            BookmarksModel.databasePath = ":memory:"
            HistoryModel.databasePath = ":memory:"

            view = viewComponent.createObject(root)
            populate()

            view.focus = true

            historyEntryClickedSpy.target = view
            historyEntryClickedSpy.clear()
            bookmarkClickedSpy.target = view
            bookmarkClickedSpy.clear()
            bookmarkRemovedSpy.target = view
            bookmarkRemovedSpy.clear()
        }

        function populate() {
            HistoryModel.add("http://example.com", "Example Com", "")
            HistoryModel.add("http://example.org", "Example Org", "")
            HistoryModel.add("http://example.net", "Example Net", "")

            BookmarksModel.add("http://example.com", "Example Com", "", "")
            BookmarksModel.add("http://example.org/bar", "Example Org Bar", "", "Folder B")
            BookmarksModel.add("http://example.org/foo", "Example Org Foo", "", "Folder B")
            BookmarksModel.add("http://example.net/a", "Example Net A", "", "Folder A")
            BookmarksModel.add("http://example.net/b", "Example Net B", "", "Folder A")
        }

        function cleanup() {
            BookmarksModel.databasePath = ""
            HistoryModel.databasePath = ""

            view.destroy()
            view = null
        }

        function goToBookmarks() {
            findChild(view, "sections").selectedIndex = 1
        }

        function test_topsites_list() {
            // add 8 more top sites so that we are beyond the limit of 10
            for (var i = 0; i < 8; i++) {
                HistoryModel.add("http://example.com/" + i, "Example Com " + i, "")
            }

            var items = getListItems(findChild(view, "topSitesList"), "topSiteItem")
            compare(items.length, 10)
            compare(items[0].title, "Example Com")
            compare(items[1].title, "Example Org")
            compare(items[2].title, "Example Net")
            for (var i = 0; i < 7; i++) {
                compare(items[i + 3].title, "Example Com " + i)
            }
        }

        function test_switch_sections_by_keyboard() {
            skip("Would fail due to UITK bug: http://pad.lv/1481233")
            var sections = findChild(view, "sections")
            var folders = findChild(view, "foldersList")
            var bookmarks = findChild(view, "bookmarksList")
            var topSites = findChild(view, "topSitesList")
            compare(sections.selectedIndex, 0)
            verify(topSites.visible)
            verify(!folders.visible)
            verify(!bookmarks.visible)

            keyClick(Qt.Key_Tab)
            compare(sections.selectedIndex, 1)
            verify(!topSites.visible)
            verify(folders.visible)
            verify(bookmarks.visible)

            keyClick(Qt.Key_Backtab)
            compare(sections.selectedIndex, 0)
        }

        function test_navigate_topsites_by_keyboard() {
            skip("fails on amd64 since the switch to Qt 5.12 (worked for all architectures before)")
            var items = getListItems(findChild(view, "topSitesList"), "topSiteItem")
            var list = findChild(view, "topSitesList")
            list.currentIndex = 0
            keyClick(Qt.Key_Right)
            // the following line fails on amd64 (not on armhf and arm64): FAIL!  : QmlTests::NewTabViewWide::test_navigate_topsites_by_keyboard() Compared values are not the same
            compare(list.currentIndex, 1)
            keyClick(Qt.Key_Right)
            compare(list.currentIndex, 2)
            keyClick(Qt.Key_Right) // ensure list does not wrap around
            compare(list.currentIndex, 2)
            keyClick(Qt.Key_Left)
            compare(list.currentIndex, 1)
            keyClick(Qt.Key_Left)
            compare(list.currentIndex, 0)
            keyClick(Qt.Key_Up)
            compare(list.currentIndex, 0)
            keyClick(Qt.Key_Left)
            compare(list.currentIndex, 0)
        }

        function test_activate_topsites_by_keyboard() {
            var items = getListItems(findChild(view, "topSitesList"), "topSiteItem")
            keyClick(Qt.Key_Return)
            compare(historyEntryClickedSpy.count, 1)
            compare(historyEntryClickedSpy.signalArguments[0][0], "http://example.com")
            keyClick(Qt.Key_Right)
            keyClick(Qt.Key_Return)
            compare(historyEntryClickedSpy.count, 2)
            compare(historyEntryClickedSpy.signalArguments[1][0], "http://example.org")
        }

        function test_activate_topsites_by_mouse() {
            var items = getListItems(findChild(view, "topSitesList"), "topSiteItem")
            clickItem(items[0])
            compare(historyEntryClickedSpy.count, 1)
            compare(historyEntryClickedSpy.signalArguments[0][0], "http://example.com")

            clickItem(items[1])
            compare(historyEntryClickedSpy.count, 2)
            compare(historyEntryClickedSpy.signalArguments[1][0], "http://example.org")

        }

        function test_remove_top_sites_by_keyboard() {
            var topSitesListView = findChild(view, "topSitesList")
            var previous = getListItems(topSitesListView, "topSiteItem")
            keyClick(Qt.Key_Delete)
            var items = getListItems(topSitesListView, "topSiteItem")
            compare(previous.length - 1, items.length)
        }
    }
}
