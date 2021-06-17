/*
 * Copyright 2015 Canonical Ltd.
 *
 * This file is part of morph-browser.
 *
 * morph-browser is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * morph-browser is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtWebEngine 1.5

Item {
    id: monitor

    visible: false

    property var webview: null

    readonly property bool killed: webview && internal.killed
    readonly property bool crashed: webview && internal.crashed

    // When the renderer process is killed (most likely by the system’s
    // OOM killer), try to reload the page once, and if this results in
    // the process being killed again within one minute, then display
    // the sad tab.

    readonly property int killedRetries: internal.killedRetries

    QtObject {
        id: internal
        property int killedRetries: 0
        property bool killed
        property bool crashed
    }

    Connections {
        target: webview
        onRenderProcessTerminated: {
             if (terminationStatus == WebEngineView.KilledTerminationStatus) {
                internal.killed = true;
                if (internal.killedRetries == 0) {
                    // Do not attempt reloading right away, this would result in a crash
                    delayedReload.restart();
                }
            }
            if (terminationStatus == WebEngineView.CrashedTerminationStatus) {
                internal.crashed = true;
            }
        }
        
        onLoadingChanged: {
            if ((loadRequest.status == WebEngineLoadRequest.LoadSucceededStatus) ||
                (loadRequest.status == WebEngineLoadRequest.LoadFailedStatus)) {
                internal.killed = false;
                internal.crashed = false;
            }
        }
    }

    Timer {
        id: delayedReload
        interval: 100
        onTriggered: {
            monitorTimer.restart()
            monitor.webview.reload()
            internal.killedRetries++
        }
    }

    Timer {
        id: monitorTimer
        interval: 60000 // 1 minute
        onTriggered: internal.killedRetries = 0
    }

    onWebviewChanged: {
        internal.killedRetries = 0
        internal.killed = false
        internal.crashed = false
        delayedReload.stop()
        monitorTimer.stop()
    }
}
