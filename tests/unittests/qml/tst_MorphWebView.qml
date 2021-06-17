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

import QtQuick 2.4
import QtTest 1.0
import Ubuntu.Test 1.0
import Ubuntu.Components 1.3
import Morph.Web 0.1

Item {
    id: root

    width: 200
    height: 200

    Component {
        id: webviewComponent
        WebView {
            anchors.fill: parent
        }
    }

    ActionList {
        id: actionList
        Action {
            id: action1
        }
        Action {
            id: action2
        }
    }

    WebbrowserTestCase {
        name: "MorphWebView"
        when: windowShown

        property var webview: null

        function init() {
            webview = webviewComponent.createObject(root)
            verify(webview != null)
            verify(waitForRendering(webview))
        }

        function cleanup() {
            webview.destroy()
        }

        function test_context_singleton() {
            var other = webviewComponent.createObject(root)
            compare(other.context, webview.context)
            other.destroy()
        }

        function loadHtmlWithHyperlink() {
            var html = '<html><body style="margin: 0"><a href="http://example.org/">'
            html += '<div style="height: 100%"></div></a></body></html>'
            webview.loadHtml(html, "file:///")
            // Ridiculously high timeout, but this appears to be needed when
            // running the tests in CI (https://launchpad.net/bugs/1599630).
            tryCompare(webview, "loading", false, 120000)
        }

        function rightClickWebview() {
            var center = centerOf(webview)
            mouseClick(webview, center.x, center.y, Qt.RightButton)
        }

        function getContextMenu() {
            return findChild(webview, "contextMenu")
        }

        function dismissContextMenu() {
            verify(getContextMenu() != null)
            var center = centerOf(webview)
            mouseClick(webview, center.x, center.y)
            verify(waitFor(function() { return getContextMenu() == null }))
        }

        /*
        function test_no_contextual_actions() {
            loadHtmlWithHyperlink()
            rightClickWebview()
            wait(500)
            compare(waitFor(getContextMenu), null)
        }

        function test_contextual_actions() {
            webview.contextualActions = actionList
            loadHtmlWithHyperlink()
            rightClickWebview()
            verify(waitFor(getContextMenu) != null)
            compare(getContextMenu().actions.children, actionList.children)
            compare(webview.contextualData.href, "http://example.org/")
            dismissContextMenu()
            compare(webview.contextualData.href, "")
        }

        function test_contextual_actions_all_disabled() {
            webview.contextualActions = actionList
            action1.enabled = false
            action2.enabled = false
            loadHtmlWithHyperlink()
            rightClickWebview()
            waitFor(getContextMenu)
            verify(waitFor(function() { return getContextMenu() == null }))
            action1.enabled = true
            action2.enabled = true
        }
        */
    }
}
