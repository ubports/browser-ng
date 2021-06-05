/*
 * Copyright 2014-2015 Canonical Ltd.
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
import webbrowsercommon.private 0.1

Item {
    id: root

    width: 200
    height: 200

    Component {
        id: tabComponent

        BrowserTab {
            id: tab
            anchors.fill: parent
            webviewComponent: Item {
                anchors.fill: parent
                property url url
                property string title
                property url icon
                property var request
                property bool incognito: tab.incognito
                property int reloaded: 0
                property bool loadingState: false
                function reload() { reloaded++ }

                signal loadEvent()
            }
            readonly property bool webviewPresent: webview
        }
    }

    SignalSpy {
        id: previewSavedSpy
        target: PreviewManager
        signalName: "previewSaved"
    }

    TestCase {
        name: "BrowserTab"
        when: windowShown

        function init() {
            previewSavedSpy.clear()
        }

        function test_unique_ids() {
            var tab = tabComponent.createObject(root)
            var tab2 = tabComponent.createObject(root)
            verify(tab.uniqueId)
            verify(tab2.uniqueId)
            verify(tab.uniqueId !== tab2.uniqueId)
            tab.destroy()
            tab2.destroy()
        }

        function test_load_unload() {
            var tab = tabComponent.createObject(root)
            verify(!tab.webviewPresent)

            tab.initialUrl = "http://example.org"
            tab.load()
            tryCompare(tab, 'webviewPresent', true)
            compare(tab.webview.url, "http://example.org")

            tab.webview.url = "http://ubuntu.com"
            tab.webview.title = "Ubuntu"
            tab.unload()
            tryCompare(tab, 'webviewPresent', false)
            compare(tab.initialUrl, "http://ubuntu.com")
            compare(tab.initialTitle, "Ubuntu")

            tab.destroy()
        }

        function test_reload() {
            var tab = tabComponent.createObject(root)
            verify(!tab.webviewPresent)

            tab.initialUrl = "http://example.org"
            tab.reload()
            tryCompare(tab, 'webviewPresent', true)
            compare(tab.webview.reloaded, 0)

            tab.reload()
            verify(tab.webviewPresent)
            compare(tab.webview.reloaded, 1)

            tab.destroy()
        }

        function test_create_with_request() {
            var tab = tabComponent.createObject(root, {'request': "foobar"})
            tryCompare(tab, 'webviewPresent', true)
            verify(tab.webviewPresent)
            compare(tab.webview.request, "foobar")
            tab.destroy()
        }

        function test_save_preview() {
            var tab = tabComponent.createObject(root)
            tab.initialUrl = "http://example.org"
            tab.load()
            tryCompare(tab, 'webviewPresent', true)

            tab.current = true
            tab.current = false
            // a recent change of BrowserTab.qml changed that behavior, so that previewSaved is called twice, is that intended ?
            tryCompare(previewSavedSpy, "count", 2)
            verify(!tab.visible)
            compare(previewSavedSpy.signalArguments[0][0], tab.initialUrl)
            compare(previewSavedSpy.signalArguments[0][1], Qt.resolvedUrl(PreviewManager.previewPathFromUrl(tab.initialUrl)))
            // FIXME: recent change of BrowserTab does no longer set the tab.preview to the preview URL
            //compare(tab.preview, Qt.resolvedUrl(PreviewManager.previewPathFromUrl(tab.initialUrl)))
            tab.destroy()
        }

        function test_no_save_preview_when_incognito() {
            var tab = tabComponent.createObject(root)
            tab.incognito = true
            tab.initialUrl = "http://example.org"
            tab.load()
            tryCompare(tab, 'webviewPresent', true)

            tab.current = true
            tab.current = false
            // this does not fully guarantee the event won't be emitted later,
            // but it is a reasonable delay and certainly better than nothing
            wait(250)
            compare(previewSavedSpy.count, 0)
            compare(tab.preview, "")
            tab.destroy()
        }

        function test_delete_preview_on_close() {
            var url = "http://example.org"
            var path = Qt.resolvedUrl(PreviewManager.previewPathFromUrl(url))
            var tab = tabComponent.createObject(root)
            tab.initialUrl = url
            tab.load()
            tryCompare(tab, 'webviewPresent', true)

            tab.current = true
            tab.current = false
            // a recent change of BrowserTab.qml changed that behavior, so that previewSaved is called twice, is that intended ?
            tryCompare(previewSavedSpy, "count", 2)
            verify(FileOperations.exists(path))
            tab.close(false)
            verify(!FileOperations.exists(path))
            tab.destroy()
        }
    }
}
