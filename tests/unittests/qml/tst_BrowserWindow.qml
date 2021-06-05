/*
 * Copyright 2016 Canonical Ltd.
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
import "../../../src/app"

Item {
    width: 200
    height: 200

    QtObject {
        id: webviewMock
        property bool isFullScreen: false
    }

    Component {
        id: windowFactory
        BrowserWindow {
            currentWebview: webviewMock
        }
    }

    SignalSpy {
        id: visibilitySpy
        target: testcase.currentWindow
        signalName: "visibilityChanged"
    }

    TestCase {
        id: testcase
        name: "BrowserWindow"
        when: windowShown

        property var currentWindow

        function init() {
            currentWindow = windowFactory.createObject(null)
            currentWindow.show()
            compare(currentWindow.visibility, Window.Windowed)
            visibilitySpy.clear()
        }

        function cleanup() {
            currentWindow.destroy()
        }

        function test_fullscreen_data() {
            return [
                {forceFullscreen: false, state: Window.Windowed},
                {forceFullscreen: false, state: Window.Minimized},
                {forceFullscreen: false, state: Window.Maximized},
                {forceFullscreen: false, state: Window.Hidden},
                {forceFullscreen: true, state: Window.FullScreen},
            ]
        }

        function test_fullscreen_on_webview_fullscreen_data() {
            return test_fullscreen_data()
        }

        function test_fullscreen_on_webview_fullscreen(data) {
            currentWindow.forceFullscreen = data.forceFullscreen
            currentWindow.visibility = data.state
            visibilitySpy.clear()
            webviewMock.isFullScreen = true
            tryCompare(visibilitySpy, "count", data.forceFullscreen ? 0 : 1)
            compare(currentWindow.visibility, Window.FullScreen)
            webviewMock.isFullScreen = false
            tryCompare(visibilitySpy, "count", data.forceFullscreen ? 0 : 2)
            compare(currentWindow.visibility, data.state)
        }

        function test_setfullscreen_data() {
            return test_fullscreen_data()
        }

        function test_setfullscreen(data) {
            currentWindow.forceFullscreen = data.forceFullscreen
            currentWindow.visibility = data.state
            visibilitySpy.clear()
            currentWindow.setFullscreen(true)
            tryCompare(visibilitySpy, "count", data.forceFullscreen ? 0 : 1)
            compare(currentWindow.visibility, Window.FullScreen)
            currentWindow.setFullscreen(false)
            tryCompare(visibilitySpy, "count", data.forceFullscreen ? 0 : 2)
            compare(currentWindow.visibility, data.state)
        }
    }
}
