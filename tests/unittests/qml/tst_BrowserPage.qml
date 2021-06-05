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
import Ubuntu.Components 1.3
import "../../../src/app"

FocusScope {
    id: root

    focus: true

    width: 200
    height: 200

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons

        property int clicked: 0
        onClicked: ++clicked
    }

    Loader {
        id: pageLoader
        anchors.fill: parent
        active: false
        focus: true
        sourceComponent: BrowserPage {
            anchors.fill: parent
            focus: true
            readonly property var theContents: theContents
            Item {
                id: theContents
                anchors.fill: parent
                focus: true
            }
        }
    }

    readonly property alias page: pageLoader.item

    SignalSpy {
        id: backSpy
        target: root.page
        signalName: "back"
    }

    Action {
        id: anAction
        objectName: "anAction"
        iconName: "like"
        property int triggered: 0
        onTriggered: ++triggered
    }

    WebbrowserTestCase {
        name: "BrowserPage"
        when: windowShown

        function longPressItem(item) {
            var center = centerOf(item)
            mousePress(item, center.x, center.y)
            mouseRelease(item, center.x, center.y, Qt.LeftButton, Qt.NoModifier, 2000)
        }

        function init() {
            pageLoader.active = true
            mouseArea.clicked = 0
            anAction.triggered = 0
            backSpy.clear()
        }

        function cleanup() {
            pageLoader.active = false
            compare(mouseArea.clicked, 0)
        }

        function test_focus_transfer() {
            verify(root.page.theContents.activeFocus)
        }

        function test_clicks_do_not_go_through() {
            clickItem(root.page, Qt.LeftButton)
            clickItem(root.page, Qt.RightButton)
            clickItem(root.page, Qt.MiddleButton)
        }

        function test_press_back_button() {
            var backButton = findChild(root.page, "back_button")
            tryCompare(backButton, "visible", true)
            clickItem(backButton)
            compare(backSpy.count, 1)
        }

        function test_esc_is_back() {
            keyClick(Qt.Key_Escape)
            compare(backSpy.count, 1)
        }

        function test_leading_actions() {
            compare(page.leadingActions.length, 0)

            page.showBackAction = false
            compare(findChild(root.page, "back_button"), null)
            compare(findChild(root.page, "anAction_button"), null)

            page.leadingActions = [anAction]
            var actionButton = findChild(root.page, "anAction_button")
            tryCompare(actionButton, "visible", true)
            clickItem(actionButton)
            compare(anAction.triggered, 1)

            page.showBackAction = true
            compare(findChild(root.page, "anAction_button"), null)
            var backButton = findChild(root.page, "back_button")
            tryCompare(backButton, "visible", true)
        }

        function test_trailing_actions() {
            compare(page.trailingActions.length, 0)

            page.trailingActions = [anAction]
            var actionButton = findChild(root.page, "anAction_button")
            tryCompare(actionButton, "visible", true)
            clickItem(actionButton)
            compare(anAction.triggered, 1)
            verify(findChild(root.page, "back_button").visible)

            page.trailingActions = []
            compare(findChild(root.page, "anAction_button"), null)
        }
    }
}
