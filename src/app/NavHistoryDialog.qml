/*
 * Copyright 2015-2016 Canonical Ltd.
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

import QtQuick 2.9
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3

Popover {
    id: navHistoryDialog

    property alias model: historyListView.model

    property bool incognito: false
    property real availableHeight
    property real availableWidth
    property real maximumWidth: units.gu(70)
    property real preferredWidth: availableWidth - units.gu(4)

    signal navigate(int offset)

    contentWidth: Math.min(preferredWidth, maximumWidth)

    grabDismissAreaEvents: true

    onVisibleChanged: if (visible) historyListView.forceActiveFocus()

    Rectangle {
        id: bgRec
        
        color: theme.palette.normal.foreground
        anchors.fill: parent
        z: -1
    }

    ScrollView {
        property real maximumHeight: navHistoryDialog.availableHeight
        property real preferredHeight:  historyListView.contentItem.height

        anchors {
            left: parent.left
            top: parent.top
            right: parent.right
        }
        height: Math.min(preferredHeight, maximumHeight)

        UbuntuListView {
            id: historyListView

            anchors.fill: parent
            currentIndex: -1
            clip: true

            delegate: ListItem {
                height: layout.height + (divider.visible ? divider.height : 0)

                onClicked: navigate(model.offset)

                MouseArea {
                    id: hover
                    
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    anchors.fill: parent
                }

                Rectangle {
                    id: hoverBg

                    z: -1
                    anchors.fill: parent
                    opacity: 0.2
                    visible: hover.containsMouse
                    color: theme.palette.normal.focus
                }
                ListItemLayout {
                    id: layout

                    title.text: model.title
                    title.color: theme.palette.normal.foregroundText

                    Favicon {
                        id: favicon
                        
                        source: model.icon
                        SlotsLayout.position: SlotsLayout.Leading;
                        shouldCache: !navHistoryDialog.incognito

                        height: width
                        width: units.gu(2)
                    }
                }
            }
        }
    }
}