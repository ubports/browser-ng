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
import QtWebEngine 1.5
import "../../../src/app"

ChromeController {
    id: controller

    Item {
        id: webviewMock
        property bool isFullScreen: false
        property var locationBarController: QtObject {
            property bool animated: false
            property int mode: controller.defaultMode
            signal show(bool animate)
        }
        signal loadingChanged(var loadRequest)
    }

    SignalSpy {
        id: showSpy
        target: webviewMock.locationBarController
        signalName: "show"
    }

    webview: webviewMock

    TestCase {
        name: "ChromeController"

        readonly property int modeAuto: 0
        readonly property int modeShown: 1
        readonly property int modeHidden: 2

        function init() {
            controller.forceHide = false
            controller.forceShow = false
            controller.defaultMode = modeAuto
            webviewMock.isFullScreen = false
            webviewMock.locationBarController.animated = false
            webviewMock.locationBarController.mode = controller.defaultMode
            showSpy.clear()
        }

        function test_change_webview_data() {
            return [
                {forceHide: false, forceShow: false, isFullScreen: false,
                 mode: modeAuto, shown: true},
                {forceHide: false, forceShow: true, isFullScreen: false,
                 mode: modeShown, shown: false},
                {forceHide: false, forceShow: false, isFullScreen: true,
                 mode: modeAuto, shown: false},
                {forceHide: false, forceShow: true, isFullScreen: true,
                 mode: modeShown, shown: false},
                {forceHide: true, forceShow: false, isFullScreen: true,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: true, isFullScreen: false,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: true, isFullScreen: true,
                 mode: modeHidden, shown: false},
            ]
        }

        function test_change_webview(data) {
            controller.webview = null
            controller.forceHide = data.forceHide
            controller.forceShow = data.forceShow
            webviewMock.isFullScreen = data.isFullScreen
            showSpy.clear()
            controller.webview = webviewMock
            compare(webviewMock.locationBarController.mode, data.mode)
            compare(showSpy.count, data.shown ? 1 : 0)
        }

        function test_change_forceHide_data() {
            return [
                {forceShow: false, isFullScreen: false,
                 modes: [modeAuto, modeHidden, modeAuto], shown: 1},
                {forceShow: true, isFullScreen: false,
                 modes: [modeShown, modeHidden, modeShown], shown: 0},
                {forceShow: false, isFullScreen: true,
                 modes: [modeHidden, modeHidden, modeHidden], shown: 0},
                {forceShow: true, isFullScreen: true,
                 modes: [modeHidden, modeHidden, modeShown], shown: 0},
            ]
        }

        function test_change_forceHide(data) {
            controller.forceShow = data.forceShow
            webviewMock.isFullScreen = data.isFullScreen
            showSpy.clear()
            controller.forceHide = false
            compare(webviewMock.locationBarController.mode, data.modes[0])
            controller.forceHide = true
            compare(webviewMock.locationBarController.mode, data.modes[1])
            controller.forceHide = false
            compare(webviewMock.locationBarController.mode, data.modes[2])
            compare(showSpy.count, data.shown)
        }

        function test_change_forceShow_data() {
            return [
                {forceHide: false, isFullScreen: false,
                 modes: [modeAuto, modeShown, modeAuto], shown: 1},
                {forceHide: true, isFullScreen: false,
                 modes: [modeHidden, modeHidden, modeHidden], shown: 0},
                {forceHide: false, isFullScreen: true,
                 modes: [modeHidden, modeShown, modeShown], shown: 0},
                {forceHide: true, isFullScreen: true,
                 modes: [modeHidden, modeHidden, modeHidden], shown: 0},
            ]
        }

        function test_change_forceShow(data) {
            controller.forceHide = data.forceHide
            webviewMock.isFullScreen = data.isFullScreen
            showSpy.clear()
            controller.forceShow = false
            compare(webviewMock.locationBarController.mode, data.modes[0])
            controller.forceShow = true
            compare(webviewMock.locationBarController.mode, data.modes[1])
            controller.forceShow = false
            compare(webviewMock.locationBarController.mode, data.modes[2])
            compare(showSpy.count, data.shown)
        }

        function test_change_fullscreen_data() {
            return [
                {forceHide: false, forceShow: false, defaultMode: modeAuto,
                 mode: modeAuto, shown: true},
                {forceHide: false, forceShow: false, defaultMode: modeShown,
                 mode: modeShown, shown: false},
                {forceHide: false, forceShow: false, defaultMode: modeHidden,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: false, defaultMode: modeAuto,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: false, defaultMode: modeShown,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: false, defaultMode: modeHidden,
                 mode: modeHidden, shown: false},
                {forceHide: false, forceShow: true, defaultMode: modeAuto,
                 mode: modeShown, shown: false},
                {forceHide: false, forceShow: true, defaultMode: modeShown,
                 mode: modeShown, shown: false},
                {forceHide: false, forceShow: true, defaultMode: modeHidden,
                 mode: modeShown, shown: false},
                {forceHide: true, forceShow: true, defaultMode: modeAuto,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: true, defaultMode: modeShown,
                 mode: modeHidden, shown: false},
                {forceHide: true, forceShow: true, defaultMode: modeHidden,
                 mode: modeHidden, shown: false},
            ]
        }

        function test_change_fullscreen(data) {
            webviewMock.isFullScreen = false
            controller.forceHide = data.forceHide
            controller.forceShow = data.forceShow
            controller.defaultMode = data.defaultMode
            showSpy.clear()
            webviewMock.isFullScreen = true
            compare(webviewMock.locationBarController.mode, modeHidden)
            compare(showSpy.count, 0)
            webviewMock.isFullScreen = false
            compare(webviewMock.locationBarController.mode, data.mode)
            compare(showSpy.count, data.shown ? 1 : 0)
        }

        function test_load_event_data() {
            var data = []
            var forceHideValues = [false, true];
            var forceShowValues = [false, true];
            var initialḾodeValues = [modeAuto, modeHidden, modeShown];
            var defaultḾodeValues = [modeAuto, modeHidden, modeShown];
            var isFullScreenValues = [false, true];

            for (var i in forceHideValues) {
                for (var j in forceShowValues) {
                    for (var k in initialḾodeValues) {
                        for (var l in defaultḾodeValues) {
                            for (var m in isFullScreenValues) {
                                data.push({forceHide: forceHideValues[i], forceShow: forceShowValues[j], initialMode: initialḾodeValues[k], 
                                           defaultMode: defaultḾodeValues[l], isFullScreen: isFullScreenValues[m]});
                            }
                        }
                    }
                }
            }
            return data
        }

        function test_load_event(data) {
            // WebEngineLoadRequest status enum
            var started = WebEngineLoadRequest.LoadStartedStatus;
            var succeeded = WebEngineLoadRequest.LoadSucceededStatus;
            var failed = WebEngineLoadRequest.LoadFailedStatus;

            controller.forceHide = data.forceHide;
            controller.forceShow = data.forceShow;
            controller.defaultMode = data.defaultMode;
            webviewMock.locationBarController.mode = data.initialMode;
            webviewMock.isFullScreen = data.isFullScreen;

            function test_sequence(sequence, modes) {
                 for (var i in sequence) {
                    
                    console.log("data: " + JSON.stringify(data))
                    var previousMode = webviewMock.locationBarController.mode;
                    showSpy.clear();
                    webviewMock.loadingChanged({status: sequence[i]});
                    
                    // check the mode
                    if (data.forceHide || data.forceShow) {
                        compare(webviewMock.locationBarController.mode, data.isFullScreen ? modeHidden : data.initialMode);
                    } else {
                        compare(webviewMock.locationBarController.mode, modes[i]);
                    }
                    
                    // check the show() call count
                    if ((sequence[i] === started) && !data.forceHide && !data.forceShow && !data.isFullScreen && (previousMode === modeAuto) ) {
                        compare(showSpy.count, 1);
                    } else {
                        compare(showSpy.count, 0);
                    }

                }
            }

            var sequence = [started, succeeded];
            var modes = [modeShown, data.defaultMode];
            test_sequence(sequence, modes);

            sequence = [started, failed];
            modes = [modeShown, data.defaultMode];
            test_sequence(sequence, modes);
        }
    }
}
