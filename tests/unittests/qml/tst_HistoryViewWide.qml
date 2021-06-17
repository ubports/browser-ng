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
import Ubuntu.Components 1.3
import webbrowserapp.private 0.1
import webbrowsertest.private 0.1
import "../../../src/app/webbrowser"

Item {
    id: root

    width: 700
    height: 500

    property var historyViewWide: historyViewWideLoader.item
    property int ctrlFCaptured: 0

    Keys.onPressed: {
        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_F)
            ctrlFCaptured++
    }

    Loader {
        id: historyViewWideLoader
        anchors.fill: parent
        active: false
        focus: true
        sourceComponent: HistoryViewWide {
            focus: true
        }
    }

    SignalSpy {
        id: historyEntryClickedSpy
        target: historyViewWide
        signalName: "historyEntryClicked"
    }

    WebbrowserTestCase {
        name: "HistoryViewWide"
        when: windowShown

        function longPressItem(item) {
            var center = centerOf(item)
            mousePress(item, center.x, center.y)
            mouseRelease(item, center.x, center.y, Qt.LeftButton, Qt.NoModifier, 2000)
        }

        function initTestCase() {
            HistoryModel.databasePath = ":memory:"
        }

        function init() {
            historyViewWideLoader.active = true
            waitForRendering(historyViewWideLoader.item)

            for (var i = 0; i < 3; ++i) {
                HistoryModel.add("http://example.org/" + i, "Example Domain " + i, "")
            }
            historyViewWide.loadModel()
            var urlsList = findChild(historyViewWide, "urlsListView")
            waitForRendering(urlsList)
            tryCompare(urlsList, "count", 3)
        }

        function cleanup() {
            HistoryModel.clearAll()
            historyViewWideLoader.active = false
            ctrlFCaptured = 0
        }

        function test_history_entry_clicked() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            historyEntryClickedSpy.clear()
            clickItem(urlsList.children[0])
            compare(historyEntryClickedSpy.count, 1)
            var args = historyEntryClickedSpy.signalArguments[0]
            var entry = urlsList.model.get(0)
            compare(args[0], entry.url)
        }

        function test_selection_mode() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            var backButton = findChild(historyViewWide, "back_button")
            var selectButton = findChild(historyViewWide, "selectAll_button")
            var deleteButton = findChild(historyViewWide, "delete_button")
            verify(backButton.visible)
            compare(selectButton, null)
            compare(deleteButton, null)
            longPressItem(urlsList.children[0])
            backButton = findChild(historyViewWide, "back_button")
            compare(backButton, null)
            selectButton = findChild(historyViewWide, "selectAll_button")
            verify(selectButton.visible)
            deleteButton = findChild(historyViewWide, "delete_button")
            verify(deleteButton.visible)
            var closeButton = findChild(historyViewWide, "close_button")
            clickItem(closeButton)
            backButton = findChild(historyViewWide, "back_button")
            verify(backButton.visible)
            verify(!selectButton.visible)
            verify(!deleteButton.visible)
        }

        function test_toggle_select_button() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            longPressItem(urlsList.children[0])
            var selectedIndices = urlsList.ViewItems.selectedIndices
            compare(selectedIndices.length, 1)
            var selectButton = findChild(historyViewWide, "selectAll_button")
            clickItem(selectButton)
            compare(selectedIndices.length, urlsList.count)
            clickItem(selectButton)
            var closeButton = findChild(historyViewWide, "close_button")
            clickItem(closeButton)
        }

        function test_delete_button() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            var deletedUrl = urlsList.model.get(0).url
            longPressItem(urlsList.children[0])
            var deleteButton = findChild(historyViewWide, "delete_button")
            clickItem(deleteButton)
            compare(urlsList.count, 2)
            for (var i = 0; i < urlsList.count; ++i) {
                verify(urlsList.model.get(i).url != deletedUrl)
            }
        }

        function test_keyboard_navigation_between_lists() {
            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var urlsList = findChild(historyViewWide, "urlsListView")
            verify(!lastVisitDateList.activeFocus)
            verify(urlsList.activeFocus)

            keyClick(Qt.Key_Left)
            verify(lastVisitDateList.activeFocus)
            verify(!urlsList.activeFocus)
            keyClick(Qt.Key_Right)
            verify(urlsList.activeFocus)
        }

        function test_search_button() {
            var searchQuery = findChild(historyViewWide, "searchQuery")
            compare(searchQuery, null)

            var searchButton = findChild(historyViewWide, "search_button")
            verify(searchButton.visible)
            clickItem(searchButton)
            verify(!searchButton.visible)

            searchQuery = findChild(historyViewWide, "searchQuery")
            verify(searchQuery.visible)
            verify(searchQuery.activeFocus)
            compare(searchQuery.text, "")

            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            typeString("2")
            compare(urlsList.count, 1)

            var closeButton = findChild(historyViewWide, "close_button")
            verify(closeButton.visible)
            clickItem(closeButton)
            verify(closeButton.visible)
            searchButton = findChild(historyViewWide, "search_button")
            tryCompare(searchButton, "visible", true)
            compare(urlsList.count, 3)

            clickItem(searchButton)
            compare(searchQuery.text, "")
        }

        function test_keyboard_navigation_for_search() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            verify(urlsList.activeFocus)
            keyClick(Qt.Key_F, Qt.ControlModifier)

            var searchQuery = findChild(historyViewWide, "searchQuery")
            verify(searchQuery.activeFocus)

            keyClick(Qt.Key_Escape)
            verify(urlsList.activeFocus)

            keyClick(Qt.Key_F, Qt.ControlModifier)
            keyClick(Qt.Key_Down)
            verify(urlsList.activeFocus)
            keyClick(Qt.Key_Up)
            verify(searchQuery.activeFocus)

            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Left)
            keyClick(Qt.Key_Up)
            verify(searchQuery.activeFocus)
        }

        function test_ctrl_f_during_search_returns_to_query() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            var datesList = findChild(historyViewWide, "lastVisitDateListView")

            verify(urlsList.activeFocus)
            verify(!historyViewWide.searchMode)
            keyClick(Qt.Key_F, Qt.ControlModifier)
            var searchQuery = findChild(historyViewWide, "searchQuery")
            verify(searchQuery.activeFocus)
            verify(historyViewWide.searchMode)

            // CTRL+F jumps back to the search box from the urls list...
            keyClick(Qt.Key_Down)
            verify(urlsList.activeFocus)
            keyClick(Qt.Key_F, Qt.ControlModifier)
            verify(searchQuery.activeFocus)

            // ...and from the dates list
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Left)
            verify(datesList.activeFocus)
            keyClick(Qt.Key_F, Qt.ControlModifier)
            verify(searchQuery.activeFocus)
        }

        function test_ctrl_f_during_select_is_swallowed() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            longPressItem(urlsList.children[0])
            verify(historyViewWide.selectMode)

            keyClick(Qt.Key_F, Qt.ControlModifier)
            wait(50) // make sure event loop has processed
            compare(ctrlFCaptured, 0)
            verify(historyViewWide.selectMode)
        }

        function test_history_entry_activated_by_keyboard() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            compare(urlsList.count, 3)
            historyEntryClickedSpy.clear()
            keyClick(Qt.Key_Enter)
            compare(historyEntryClickedSpy.count, 1)
            var args = historyEntryClickedSpy.signalArguments[0]
            var entry = urlsList.model.get(0)
            compare(String(args[0]), String(entry.url))

            // now try the same during a search
            historyEntryClickedSpy.clear()
            keyClick(Qt.Key_F, Qt.ControlModifier)
            typeString("dom")
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Enter)
            compare(historyEntryClickedSpy.count, 1)
            args = historyEntryClickedSpy.signalArguments[0]
            entry = urlsList.model.get(0)
            compare(String(args[0]), String(entry.url))
        }

        function test_search_highlight() {
            function wraphtml(text) { return "<html>%1</html>".arg(text) }
            function highlight(term) {
                return "<b><font color=\"%1\">%2</font></b>".arg("#335280").arg(term)
            }

            var searchButton = findChild(historyViewWide, "search_button")
            var urlsList = findChild(historyViewWide, "urlsListView")
            clickItem(searchButton)
            verify(!searchButton.visible)

            var term = "2"
            typeString(term)
            var items = getListItems(urlsList, "historyDelegate")
            compare(items.length, 1)
            compare(items[0].title, wraphtml("Example Domain " + highlight(term)))

            var closeButton = findChild(historyViewWide, "close_button")
            clickItem(closeButton)
            verify(!historyViewWide.searchMode)
            searchButton = findChild(historyViewWide, "search_button")
            tryCompare(searchButton, "visible", true)
            clickItem(searchButton)
            tryCompare(historyViewWide, "searchMode", true)
            var searchQuery = findChild(historyViewWide, "searchQuery")
            verify(searchQuery.activeFocus)

            var terms = ["1", "Example"]
            typeString(terms.join(" "))
            tryCompare(searchQuery, "text", "1 Example")
            items = getListItems(urlsList, "historyDelegate")
            compare(items.length, 1)
            compare(items[0].title, wraphtml("%1 Domain %0"
                                             .arg(highlight(terms[0]))
                                             .arg(highlight(terms[1]))))
        }

        function test_search_updates_dates_list() {
            function getDateItem(date) {
                var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
                var dates = getListItems(lastVisitDateList, "lastVisitDateDelegate")
                var items = dates.filter(function(item) {
                    return item.lastVisitDate.valueOf() === date.valueOf()
                })
                if (items.length > 0) return items.pop()
                else return null
            }
            function returnToDatesList() {
                keyClick(Qt.Key_Down)
                keyClick(Qt.Key_Left)
            }

            var today = new Date()
            today = new Date(today.getFullYear(), today.getMonth(), today.getDate())
            var youngest = new Date(1912, 6, 23)
            var model = HistoryModel
            model.addByDate("https://en.wikipedia.org/wiki/Alan_Turing", "Alan Turing", youngest)
            model.addByDate("https://en.wikipedia.org/wiki/Alonzo_Church", "Alonzo Church", new Date(1903, 6, 14))

            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var dates = getListItems(lastVisitDateList, "lastVisitDateDelegate")
            var urlsListView = findChild(historyViewWide, "urlsListView")
            var urls = getListItems(urlsListView, "historyDelegate")
            compare(dates.length, 4)
            compare(urls.length, 5)

            // select a date that has search results in it and verify it is
            // still the currently selected one after the search.
            var testItem = getDateItem(youngest)
            clickItem(testItem)
            verify(testItem.activeFocus)
            keyClick(Qt.Key_F, Qt.ControlModifier)
            var searchQuery = findChild(historyViewWide, "searchQuery")
            typeString("Alan")
            urls = getListItems(urlsListView, "historyDelegate")
            compare(urls.length, 1)
            returnToDatesList()
            verify(testItem.activeFocus)

            // change the search terms so that it will display more items, but
            // since we have a selected date, we will see only one
            keyClick(Qt.Key_F, Qt.ControlModifier)
            tryCompare(searchQuery, "activeFocus", true)
            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Backspace)
            tryCompare(searchQuery, "text", "Al")
            returnToDatesList()
            verify(testItem.activeFocus)
            urls = getListItems(urlsListView, "historyDelegate")
            compare(urls.length, 1)

            // change the search terms so that the current date will not be
            // included in the results
            keyClick(Qt.Key_F, Qt.ControlModifier)
            typeString("onzo")
            compare(searchQuery.text, "Alonzo")
            returnToDatesList()
            testItem = getDateItem(youngest)
            compare(testItem, null)
            urls = getListItems(urlsListView, "historyDelegate")
            compare(urls.length, 1)

            // verify that the current item has reverted to the first in the
            // dates list ("all dates")
            compare(lastVisitDateList.currentIndex, 0)

            // if widen the search again now, we should see both results again
            keyClick(Qt.Key_F, Qt.ControlModifier)
            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Backspace)
            keyClick(Qt.Key_Backspace)
            compare(searchQuery.text, "Al")
            urls = getListItems(urlsListView, "historyDelegate")
            compare(urls.length, 2)
        }

        function test_delete_key_at_urls_list_view() {
            var urlsList = findChild(historyViewWide, "urlsListView")
            keyClick(Qt.Key_Right)
            verify(urlsList.activeFocus)
            compare(urlsList.count, 3)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 2)

            // now try the same while in a search
            keyClick(Qt.Key_F, Qt.ControlModifier)
            typeString("dom")
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 1)
        }

        function test_delete_key_at_last_visit_date() {
            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var urlsList = findChild(historyViewWide, "urlsListView")
            keyClick(Qt.Key_Left)
            verify(lastVisitDateList.activeFocus)
            compare(lastVisitDateList.currentIndex, 0)
            keyClick(Qt.Key_Down)
            compare(lastVisitDateList.currentIndex, 1)
            compare(urlsList.count, 3)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 0)
        }

        function test_delete_key_at_all_history() {
            var lastVisitDateList = findChild(historyViewWide, "lastVisitDateListView")
            var urlsList = findChild(historyViewWide, "urlsListView")
            keyClick(Qt.Key_Left)
            verify(lastVisitDateList.activeFocus)
            compare(lastVisitDateList.currentIndex, 0)
            compare(urlsList.count, 3)
            keyClick(Qt.Key_Delete)
            compare(urlsList.count, 0)
        }
    }
}
