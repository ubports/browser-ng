/*
* Copyright 2016 Canonical Ltd.
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
import Ubuntu.Components 1.3

Item {
    id: root

    property var webview: null
    property real collapsedWidth: 0

    states: [
        State {
            name: "hidden"
        },
        State {
            name: "collapsed"
        },
        State {
            name: "expanded"
        }
    ]
    state: "hidden"
    visible: state != "hidden"

    width: (state == "expanded")
               ? Math.max(collapsedWidth, label.contentWidth + label.anchors.margins * 2)
               : collapsedWidth
    Behavior on width {
        UbuntuNumberAnimation {
            duration: UbuntuAnimation.SnapDuration
        }
    }

    Rectangle {
        color: theme.palette.normal.foreground
        border {
            width: units.dp(1)
            color: theme.palette.normal.base
        }
        anchors.fill: parent
    }

    Timer {
        id: timer
        interval: 1000
        onTriggered: root.state = "expanded"
    }

    Label {
        id: label
        anchors {
            verticalCenter: parent.verticalCenter
            margins: units.gu(1)
            left: parent.left
            right: (root.state == "expanded") ? undefined : parent.right
        }
        fontSize: "small"
        elide: (root.state == "expanded") ? Text.ElideNone : Text.ElideRight
        text: ""
        onTextChanged: {
            if (text) {
                if (root.state == "hidden") {
                    root.state = "collapsed"
                }
                timer.restart()
            } else {
                timer.stop()
                root.state = "hidden"
            }
        }
    }
    
    Connections {
        target: root.webview
        onLinkHovered: label.text = hoveredUrl.toString()
    }
}
