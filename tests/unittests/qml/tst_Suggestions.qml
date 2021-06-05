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

Item {
    width: 300
    height: 300

    ListModel {
        id: model1
        readonly property bool displayUrl: true
        readonly property url icon: ""
    }

    readonly property var model2: []

    ListModel {
        id: model3
        readonly property bool displayUrl: true
        readonly property url icon: ""
    }

    Suggestions {
        id: suggestions

        focus: true
        anchors.fill: parent

        models: [model1, model2, model3]
        searchTerms: []
    }

    SignalSpy {
        id: activatedSpy
        target: suggestions
        signalName: "activated"
    }

    UbuntuTestCase {
        name: "Suggestions"
        when: windowShown

        function init() {
            model1.append({"title": "lorem ipsum", "url": "http://model1/item1"})
            model1.append({"title": "a+ rating", "url": "http://model1/item2"})
            model2.icon = ""
            model2.push({"title": "Tom & Jerry", "url": "http://model2/item1"})
            model2.push({"title": "$1 in €", "url": "http://model2/item2"})
            model2.push({"title": "foo | bar | baz", "url": "http://model2/item3"})
            model3.append({"title": "(a+b)^2", "url": "http://model3/item1"})
            model3.append({"title": "Çà et là", "url": "http://model3/item2"})
            compare(suggestions.count, 7)
            activatedSpy.clear()
        }

        function cleanup() {
            activatedSpy.clear()
            model3.clear()
            model2.splice(0, 3)
            model1.clear()
            compare(suggestions.count, 0)
        }

        function test_highlighting_data() {
            function highlight(term) {
                return "<b><font color=\"%1\">%2</font></b>".arg("#335280").arg(term)
            }

            return [
                {terms: [], index: 0, title: "lorem ipsum"},
                {terms: ["a+"], index: 1, title: "<html>%1 rating</html>".arg(highlight("a+"))},
                {terms: ["a+"], index: 5, title: "<html>(%1b)^2</html>".arg(highlight("a+"))},
                {terms: ["tom", "jerry"], index: 2, title: "<html>%1 &amp; %2</html>".arg(highlight("Tom")).arg(highlight("Jerry"))},
                {terms: ["$"], index: 3, title: "<html>%991 in €</html>".arg(highlight("$"))},
                {terms: ["|"], index: 4, title: "<html>foo %1 bar %1 baz</html>".arg(highlight("|"))},
                {terms: ["(", ")"], index: 5, title: "<html>%1a+b%2^2</html>".arg(highlight("(")).arg(highlight(")"))},
                {terms: ["à", "ET"], index: 6, title: "<html>Ç%1 %2 l%1</html>".arg(highlight("à")).arg(highlight("et"))},
            ]
        }

        function test_highlighting(data) {
            suggestions.searchTerms = data.terms
            var delegate = findChild(suggestions, "suggestionDelegate_" + data.index)
            compare(delegate.title, data.title)
        }

        function test_mouseActivation() {
            var delegate = findChild(suggestions, "suggestionDelegate_4")
            var center = centerOf(delegate)
            mouseClick(delegate, center.x, center.y)
            compare(activatedSpy.count, 1)
            compare(activatedSpy.signalArguments[0][0], "http://model2/item3")
        }

        function test_keyboardActivation() {
            var listview = findChild(suggestions, "suggestionsList")
            compare(listview.currentIndex, 0)
            keyClick(Qt.Key_Down)
            keyClick(Qt.Key_Down)
            compare(listview.currentIndex, 2)
            keyClick(Qt.Key_Return)
            compare(activatedSpy.count, 1)
            compare(activatedSpy.signalArguments[0][0], "http://model2/item1")
        }
    }
}
