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
import QtTest 1.0
import "../../../src/app/webbrowser"

Item {
    width: 200
    height: 200

    Item {
        id: webviewMock
        signal linkHovered(url hoveredUrl)
    }

    Loader {
        id: loader
        active: false
        sourceComponent: HoveredUrlLabel {
            webview: webviewMock
        }
    }

    SignalSpy {
        id: visibleSpy
        target: loader.item
        signalName: "visibleChanged"
    }

    SignalSpy {
        id: stateSpy
        target: loader.item
        signalName: "stateChanged"
    }

    TestCase {
        name: "HoveredUrlLabel"
        when: windowShown

        readonly property var label: loader.item

        function init() {
            visibleSpy.clear()
            stateSpy.clear()
            loader.active = true
        }

        function cleanup() {
            loader.active = false
        }

        function test_states() {
            compare(label.state, "hidden")
            compare(stateSpy.count, 0)
            verify(!label.visible)
            compare(visibleSpy.count, 0)

            webviewMock.linkHovered("http://example.org")
            compare(label.state, "collapsed")
            compare(stateSpy.count, 1)
            verify(label.visible)
            compare(visibleSpy.count, 1)

            webviewMock.linkHovered("http://example.com")
            compare(label.state, "collapsed")
            compare(stateSpy.count, 1)
            verify(label.visible)
            compare(visibleSpy.count, 1)

            stateSpy.clear()
            stateSpy.wait(2000)
            compare(label.state, "expanded")
            compare(stateSpy.count, 1)
            verify(label.visible)
            compare(visibleSpy.count, 1)

            webviewMock.linkHovered("http://ubuntu.com")
            compare(label.state, "expanded")
            compare(stateSpy.count, 1)
            verify(label.visible)
            compare(visibleSpy.count, 1)

            webviewMock.linkHovered("")
            compare(label.state, "hidden")
            compare(stateSpy.count, 2)
            verify(!label.visible)
            compare(visibleSpy.count, 2)
        }
    }
}
