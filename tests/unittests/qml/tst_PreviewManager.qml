/*
 * Copyright 2015 Canonical Ltd.
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
import Ubuntu.Test 1.0
import "../../../src/app/webbrowser"
import webbrowsercommon.private 0.1
import webbrowserapp.private 0.1
import webbrowsertest.private 0.1

Item {
    id: root

    width: 800
    height: 600

    SignalSpy {
        id: previewSavedSpy
        target: PreviewManager
        signalName: "previewSaved"
    }

    QtObject {
        id: grabResultMock
        function saveToFile(path) {
            TestContext.createFile(path);
            return true
        }
    }

    QtObject {
        id: grabResultFailMock
        function saveToFile(path) { return false }
    }

    UbuntuTestCase {
        name: "PreviewManager"
        when: windowShown

        property string baseUrl: "http://example.com/"

        function initTestCase() {
            HistoryModel.databasePath = ":memory:"
        }

        function init() {
            previewSavedSpy.clear()
            verify(TestContext.removeDirectory(PreviewManager.capturesDir))
        }

        function populate(count, createPreviewFiles) {
            for (var i = 0; i < 11; i++) {
                var url = baseUrl + i
                HistoryModel.add(url, "Example Com" + i, "")
                if (createPreviewFiles) {
                    var path = PreviewManager.previewPathFromUrl(url)
                    console.log("the preview path " + path + " for url " + url + " is created.")
                    TestContext.createFile(path)
                    verify(FileOperations.exists(Qt.resolvedUrl(path)))
                }
            }
        }

        function cleanup() {
            HistoryModel.clearAll()
        }

        function test_topsites_not_deleted() {
            populate(11, true)
            for (var i = 0; i < 11; i++) {
                var url = baseUrl + i
                PreviewManager.checkDelete(url)
                var path = Qt.resolvedUrl(PreviewManager.previewPathFromUrl(url))

                // verify that only the item that is outside of the top 10 list
                // gets deleted
                if (i < 10) verify(FileOperations.exists(path))
                else verify(!FileOperations.exists(path))
            }
        }

        function test_save_preview() {
            var file = Qt.resolvedUrl(PreviewManager.previewPathFromUrl(baseUrl))

            PreviewManager.saveToDisk(grabResultMock, baseUrl)
            verify(FileOperations.exists(file))
            compare(previewSavedSpy.count, 1)
            compare(previewSavedSpy.signalArguments[0][0], baseUrl)
            compare(previewSavedSpy.signalArguments[0][1], file)
        }

        function test_save_preview_fail() {
            var path = PreviewManager.previewPathFromUrl(baseUrl)
            var file = Qt.resolvedUrl(path)

            ignoreWarning("Failed to save preview to disk for %1 (path is %2)".arg(baseUrl).arg(path))
            PreviewManager.saveToDisk(grabResultFailMock, baseUrl)
            verify(!FileOperations.exists(file))
            compare(previewSavedSpy.count, 1)
            compare(previewSavedSpy.signalArguments[0][0], baseUrl)
            compare(previewSavedSpy.signalArguments[0][1], "")
        }
    }
}
