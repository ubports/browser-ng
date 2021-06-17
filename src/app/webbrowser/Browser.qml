/*
 * Copyright 2013-2017 Canonical Ltd.
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

import QtQuick 2.5
import QtQuick.Window 2.2
import QtGraphicalEffects 1.0
import QtSystemInfo 5.5
import QtWebEngine 1.10
import Qt.labs.settings 1.0
import Morph.Web 0.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import Ubuntu.Content 1.3
import QtQuick.Controls 2.2 as QQC2
import webbrowserapp.private 0.1
import webbrowsercommon.private 0.1
import "../actions" as Actions
import "../UrlUtils.js" as UrlUtils
import ".." as Common
import "." as Local

Common.BrowserView {
    id: browser

    property Settings settings
    property var bookmarksModel: BookmarksModel

    currentWebview: tabsModel && tabsModel.currentTab ? tabsModel.currentTab.webview : null

    TabChrome {
        id: invisibleTabChrome
        visible: false
    }

    property bool incognito: false

    property var tabsModel: TabsModel {
        // These methods are required by the TabsBar component
        readonly property int selectedIndex: currentIndex

        function addTab() {
            internal.openUrlInNewTab("", true, true, count)
        }

        function addExistingTab(tab) {
            add(tab);

            browser.bindExistingTab(tab);
        }

        function moveTab(from, to) {
            if (from === to
                || from < 0 || from >= count
                || to < 0 || to >= count) {
                return;
            }

            move(from, to);
        }

        function removeTab(index) {
            internal.closeTab(index, false);
        }

        function removeTabWithoutDestroying(index) {
            internal.closeTab(index, true);
        }

        function selectTab(index) {
            internal.switchToTab(index, true);
        }
    }

    property Common.BrowserWindow thisWindow
    property Component windowFactory

    function serializeTabState(tab) {
        var state = {};
        state.uniqueId = tab.uniqueId;
        state.url = tab.url.toString();
        state.title = tab.title;
        state.icon = tab.icon.toString();
        state.preview = Qt.resolvedUrl(PreviewManager.previewPathFromUrl(tab.url)).toString();
        return state;
    }

    function restoreTabState(state) {
        var properties = {'initialUrl': state.url, 'initialTitle': state.title,
                          'uniqueId': state.uniqueId, 'initialIcon': state.icon,
                          'preview': state.preview}
        return createTab(properties)
    }

    function createTab(properties) {
        return internal.createTabHelper(properties)
    }

    function bindExistingTab(tab) {
        Reparenter.reparent(tab, tabContainer);

        var properties = internal.buildContextProperties();

        for (var prop in properties) {
            tab[prop] = properties[prop];
        }

        // Ensure that we have switched to the tab
        // otherwise chrome position can break
        internal.switchToTab(tabsModel.count - 1, true);
    }

    signal newWindowRequested(bool incognito)
    signal newWindowFromTab(var tab, var callback)
    signal openLinkInNewWindowRequested(url url, bool incognito)
    signal openLinkInNewTabRequested(url url, bool background)
    signal shareLinkRequested(url linkUrl, string title)
    signal shareTextRequested(string text)

    onOpenLinkInNewTabRequested: {
        internal.openUrlInNewTab(url, !background, true, tabsModel.selectedIndex + 1)
    }

    onShareLinkRequested: {

        internal.shareLink(linkUrl, title);
    }

    onShareTextRequested: {

        internal.shareText(text)
    }

    Connections {
        target: currentWebview

        /* Note that we are connecting the mediaAccessPermissionRequested signal
           on the current webview only because we want all the tabs that are not
           visible to automatically deny the request but emit the signal again
           if the same origin requests permissions (which is the default
           behavior in oxide if we don't connect a signal handler), so that we
           can pop-up a dialog asking the user for permission.

           Design is working on a new component that allows per-tab non-modal
           dialogs that will allow asking permission to the user without blocking
           interaction with the rest of the page or the window. When ready all
           tabs will have their mediaAccessPermissionRequested signal handled by
           creating one of these new dialogs.
        */
        //onMediaAccessPermissionRequested: PopupUtils.open(Qt.resolvedUrl("../MediaAccessDialog.qml"), null, { request: request })

        // this opens the file as download
        onPdfPrintingFinished: {

            if (success)
            {
             internal.openUrlInNewTab("file://%1".arg(filePath.replace(/\W/g, encodeURIComponent)), false)
            }
            else
            {
              console.debug(incognito ? "creating pdf failed" : "creating pdf %1 failed".arg(filePath))
            }
        }

        onNavigationRequested: {

            var url = request.url;
            var isMainFrame = request.isMainFrame;

            // for file urls we set currentDomain to "scheme:file", because there is no host
            var currentDomain = UrlUtils.schemeIs(currentWebview.url, "file") ? "scheme:file" : UrlUtils.extractHost(currentWebview.url);

            // handle custom schemes
            if (UrlUtils.hasCustomScheme(url))
            {
                if (! internal.areCustomUrlSchemesAllowed(currentDomain))
                {
                  request.action = WebEngineNavigationRequest.IgnoreRequest;

                  var allowCustomSchemesDialog = PopupUtils.open(Qt.resolvedUrl("../AllowCustomSchemesDialog.qml"), currentWebview);
                  allowCustomSchemesDialog.url = url;
                  allowCustomSchemesDialog.domain = currentDomain;
                  allowCustomSchemesDialog.showAllowPermanentlyCheckBox = ! browser.incognito;
                  allowCustomSchemesDialog.allow.connect(function() {internal.allowCustomUrlSchemes(currentDomain, false);
                                                                     internal.navigateToUrlAsync(url);
                                                                   }
                                                      );
                  allowCustomSchemesDialog.allowPermanently.connect(function() {internal.allowCustomUrlSchemes(currentDomain, true);
                                                                                internal.navigateToUrlAsync(url);
                                                                               }
                                                                   );
                }
                return;
            }

            // handle domain permissions
            var requestDomain = UrlUtils.schemeIs(url, "file") ? "scheme:file" : UrlUtils.extractHost(url);
            var requestDomainWithoutSubdomain = DomainPermissionsModel.getDomainWithoutSubdomain(requestDomain);
            var currentDomainWithoutSubdomain = DomainPermissionsModel.getDomainWithoutSubdomain(UrlUtils.extractHost(currentWebview.url));
            var domainPermission = DomainPermissionsModel.getPermission(requestDomainWithoutSubdomain);

            if (domainPermission !== DomainPermissionsModel.NotSet)
            {
                if (isMainFrame) {
                  DomainPermissionsModel.setRequestedByDomain(requestDomainWithoutSubdomain, "", browser.incognito);
                }
                else if (requestDomainWithoutSubdomain !== currentDomainWithoutSubdomain) {
                  DomainPermissionsModel.setRequestedByDomain(requestDomainWithoutSubdomain, currentDomainWithoutSubdomain, browser.incognito);
                }
            }

            if (domainPermission === DomainPermissionsModel.Blocked)
            {
                if (isMainFrame)
                {
                    var alertDialog = PopupUtils.open(Qt.resolvedUrl("../AlertDialog.qml"), browser.currentWebview);
                    alertDialog.title = i18n.tr("Blocked domain");
                    alertDialog.message = i18n.tr("Blocked navigation request to domain %1.").arg(requestDomainWithoutSubdomain);
                }
                request.action = WebEngineNavigationRequest.IgnoreRequest;
                return;
            }

            if ((domainPermission === DomainPermissionsModel.NotSet) && DomainPermissionsModel.whiteListMode)
            {
                var allowOrBlockDialog = PopupUtils.open(Qt.resolvedUrl("../AllowOrBlockDomainDialog.qml"), currentWebview);
                allowOrBlockDialog.domain = requestDomainWithoutSubdomain;
                if (isMainFrame)
                {
                    allowOrBlockDialog.parentDomain = "";
                    allowOrBlockDialog.allow.connect(function() {
                        DomainPermissionsModel.setRequestedByDomain(requestDomainWithoutSubdomain, "", browser.incognito);
                        DomainPermissionsModel.setPermission(requestDomainWithoutSubdomain, DomainPermissionsModel.Whitelisted, browser.incognito);
                        currentWebview.url = url;
                    });
                }
                else
                {
                    allowOrBlockDialog.parentDomain = currentDomainWithoutSubdomain;
                    allowOrBlockDialog.allow.connect(function() {
                        DomainPermissionsModel.setRequestedByDomain(requestDomainWithoutSubdomain, currentDomainWithoutSubdomain, browser.incognito);
                        DomainPermissionsModel.setPermission(requestDomainWithoutSubdomain, DomainPermissionsModel.Whitelisted, browser.incognito);
                        var alertDialog = PopupUtils.open(Qt.resolvedUrl("../AlertDialog.qml"), browser.currentWebview);
                        alertDialog.title = i18n.tr("Whitelisted domain");
                        alertDialog.message = i18n.tr("domain %1 is now whitelisted, it will be active on the next page reload.").arg(requestDomainWithoutSubdomain);
                    });
                }
                allowOrBlockDialog.block.connect(function() {
                    DomainPermissionsModel.setRequestedByDomain(requestDomainWithoutSubdomain, isMainFrame ? "" : currentDomainWithoutSubdomain, browser.incognito);
                    DomainPermissionsModel.setPermission(requestDomainWithoutSubdomain, DomainPermissionsModel.Blocked, browser.incognito);
                  });
                request.action = WebEngineNavigationRequest.IgnoreRequest;
                return;
            }

            // handle user agents
            if (isMainFrame)
            {
                currentWebview.hideContextMenu();
                var newUserAgentId = (UserAgentsModel.count > 0) ? DomainSettingsModel.getUserAgentId(requestDomain) : 0;

                // change of the custom user agent
                if (newUserAgentId !== currentWebview.context.userAgentId)
                {
                    currentWebview.context.userAgentId = newUserAgentId;
                    currentWebview.context.customUserAgent = (newUserAgentId > 0) ? UserAgentsModel.getUserAgentString(newUserAgentId) : "";

		    // for some reason when letting through the request, another navigation request will take us back to the
                    // to the previous page. Therefore we block it first and navigate to the new url with the correct user agent.
                    request.action = WebEngineNavigationRequest.IgnoreRequest;
                    currentWebview.url = url;
                    return;
                }
                else
                {
                    currentWebview.context.__ua.setDesktopMode(browser.settings ? browser.settings.setDesktopMode : false);
                    console.log("user agent: " + currentWebview.context.httpUserAgent);
                }
            }
        }
    }

    currentWebcontext: SharedWebContext.sharedContext
    defaultVideoCaptureDeviceId: settings.defaultVideoDevice ? settings.defaultVideoDevice : ""

    onDefaultVideoCaptureMediaIdUpdated: {
        if (!settings.defaultVideoDevice) {
            settings.defaultVideoDevice = defaultVideoCaptureDeviceId
        }
    }

    InputDeviceModel {
        id: miceModel
        filter: InputInfo.Mouse
    }

    InputDeviceModel {
        id: touchPadModel
        filter: InputInfo.TouchPad
    }

    InputDeviceModel {
        id: touchScreenModel
        filter: InputInfo.TouchScreen
    }

    Common.FilteredKeyboardModel {
        id: keyboardModel
    }

    actions: [
        Actions.GoTo {
            onTriggered: currentWebview.url = value
        },
        Actions.Back {
            enabled: currentWebview ? currentWebview.canGoBack : false
            onTriggered: {
                if (currentWebview.loading) {
                    currentWebview.stop()
                }
                currentWebview.goBack()
            }
        },
        Actions.Forward {
            enabled: currentWebview ? currentWebview.canGoForward : false
            onTriggered: {
                if (currentWebview.loading) {
                    currentWebview.stop()
                }
                currentWebview.goForward()
            }
        },
        Actions.Reload {
            enabled: currentWebview
            onTriggered: currentWebview.reload()
        },
        Actions.Bookmark {
            enabled: currentWebview
            // QtWebEngine icons are provided as e.g. image://favicon/https://duckduckgo.com/favicon.ico
            onTriggered: internal.addBookmark(currentWebview.url, currentWebview.title, (UrlUtils.schemeIs(currentWebview.icon, "image") && UrlUtils.hostIs(currentWebview.icon, "favicon")) ? currentWebview.icon.toString().substring(("image://favicon/").length) : currentWebview.icon)
        },
        Actions.NewTab {
            onTriggered: internal.openUrlInNewTab("", true)
        },
        Actions.ClearHistory {
            onTriggered: HistoryModel.clearAll()
        },
        Actions.FindInPage {
            enabled: !chrome.findInPageMode && !newTabViewLoader.active
            onTriggered: {
                chrome.findInPageMode = true
                chrome.focus = true
            }
        }
    ]

    FocusScope {
        id: contentsContainer
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            top: chrome.bottom
        }
        visible: !settingsViewLoader.active && !historyViewLoader.active && !bookmarksViewLoader.active && !downloadsViewLoader.active

        FocusScope {
            id: tabContainer
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            height: parent.height - osk.height - bottomEdgeBar.height
            // disable when newTabView is shown otherwise webview can capture drag events
            // do not use visible otherwise when a new tab is opened the locationBarController.offset
            // doesn't get updated, causing the Chrome to disappear
            enabled: !newTabViewLoader.active

            focus: !errorSheetLoader.focus &&
                   !invalidCertificateErrorSheetLoader.focus &&
                   !newTabViewLoader.focus &&
                   !sadTabLoader.focus

            Keys.onPressed: {
                if (tabContainer.visible && (event.key === Qt.Key_Backspace)) {
                    // Not handled as a window-level shortcut as it would take
                    // precedence over backspace events in HTML text fields
                    // (https://launchpad.net/bugs/1569938).
                    if (event.modifiers === Qt.NoModifier) {
                        internal.historyGoBack()
                        event.accepted = true
                    } else if (event.modifiers === Qt.ShiftModifier) {
                        internal.historyGoForward()
                        event.accepted = true
                    }
                }
            }
        }

        Loader {
            id: errorSheetLoader
            anchors {
                fill: tabContainer
            }
            Component.onCompleted: setSource("../ErrorSheet.qml", {
                                                 "visible": Qt.binding(function(){ return currentWebview ? (! currentWebview.loading && currentWebview.lastLoadFailed) : false;}),
                                                 "url": Qt.binding(function(){ return currentWebview ? currentWebview.url : "";}),
                                                 "errorString" : Qt.binding(function() {return currentWebview ? currentWebview.lastLoadRequestErrorString : "";}),
                                                 "errorDomain" : Qt.binding(function() {return currentWebview ? currentWebview.lastLoadRequestErrorDomain : -1;}),
                                                 "canGoBack" : Qt.binding(function() {return currentWebview && currentWebview.canGoBack;})
                                             })
            Connections {
                target: errorSheetLoader.item
                onBackToSafetyClicked: currentWebview.goBack()
                onRefreshClicked: currentWebview.reload()
            }

            focus: item && item.visible
            asynchronous: true
        }

        Loader {
            id: invalidCertificateErrorSheetLoader
            anchors {
                fill: tabContainer
                topMargin: (chrome.state == "shown") ? chrome.height : 0
            }
            Component.onCompleted: setSource("../InvalidCertificateErrorSheet.qml", {
                                                 "visible": Qt.binding(function(){ return currentWebview && currentWebview.certificateError != null }),
                                                 "certificateError": Qt.binding(function(){ return currentWebview ? currentWebview.certificateError : null })
                                             })
            Connections {
                target: invalidCertificateErrorSheetLoader.item
                onAllowed: {
                    // Automatically allow future requests involving this
                    // certificate for the duration of the session.
                    internal.allowCertificateError(currentWebview.certificateError)
                    currentWebview.resetCertificateError()
                }
                onDenied: {
                    currentWebview.resetCertificateError()
                }
            }
            focus: item && item.visible
            asynchronous: true
        }

        Loader {
            id: newTabViewLoader

            anchors {
                fill: tabContainer
            }
            clip: true  // prevents component from overlapping bottom edge etc

            // Avoid loading the new tab view if the webview has or will have content
            Connections {
                target: tabsModel.currentTab
                onEmptyChanged: newTabViewLoader.setActive(tabsModel.currentTab.empty)
            }
            Connections {
                target: tabsModel
                onCurrentTabChanged: newTabViewLoader.setActive(tabsModel.currentTab && tabsModel.currentTab.empty)
            }
            active: false
            focus: active
            asynchronous: true

            Connections {
                target: browser
                onWideChanged: newTabViewLoader.selectTabView()
            }
            Component.onCompleted: newTabViewLoader.selectTabView()

            // XXX: this is a workaround for bug #1659435 caused by QTBUG-54657.
            // New tab view was sometimes overlaid on top of other tabs because
            // it was not unloaded even though active was set to false.
            // Ref.: https://launchpad.net/bugs/1659435
            //       https://bugreports.qt.io/browse/QTBUG-54657
            function setActive(active) {
                if (active) {
                    if (newTabViewLoader.source == "") {
                        selectTabView();
                    }
                } else {
                    newTabViewLoader.setSource("", {});
                }
                newTabViewLoader.active = active;
            }

            function selectTabView() {
                var source = browser.incognito ? "NewPrivateTabView.qml" :
                                                 (browser.wide ? "NewTabViewWide.qml" :
                                                                 "NewTabView.qml");
                var properties = browser.incognito ? {} : {"settingsObject": settings,
                                                           "focus": true};

                newTabViewLoader.setSource(source, properties);
            }

            Connections {
                target: newTabViewLoader.item && !browser.incognito ? newTabViewLoader.item : null
                onBookmarkClicked: {
                    chrome.requestedUrl = url
                    currentWebview.url = url
                    tabContainer.forceActiveFocus()
                }
                onBookmarkRemoved: BookmarksModel.remove(url)
                onHistoryEntryClicked: {
                    chrome.requestedUrl = url
                    currentWebview.url = url
                    tabContainer.forceActiveFocus()
                }
            }
            Keys.onUpPressed: chrome.focus = true
        }

        Loader {
            id: sadTabLoader
            anchors {
                fill: tabContainer
                topMargin: (chrome.state == "shown") ? chrome.height : 0
            }

            active: webProcessMonitor.crashed || (webProcessMonitor.killed && !currentWebview.loading)
            focus: active

            Component.onCompleted: setSource("SadTab.qml", {
                                                 "webview": Qt.binding(function () {return browser.currentWebview})
                                             })
            Connections {
                target: sadTabLoader.item
                onCloseTabRequested: internal.closeCurrentTab()
            }

            Common.WebProcessMonitor {
                id: webProcessMonitor
                webview: currentWebview
            }

            asynchronous: true
        }

        HoveredUrlLabel {
            anchors {
                left: tabContainer.left
                leftMargin: units.dp(-1)
                bottom: tabContainer.bottom
                bottomMargin: units.dp(-1)
            }
            height: units.gu(3)
            collapsedWidth: Math.min(units.gu(40), tabContainer.width)
            webview: browser.currentWebview
        }
    }

    FocusScope {
        id: recentView
        objectName: "recentView"

        anchors.fill: parent
        visible: bottomEdgeHandle.dragging || tabslist.animating || (state == "shown")
        onVisibleChanged: {
            if (visible) {

                currentWebview.hideContextMenu();
                chrome.state = "hidden";
            }
            else {
                chrome.state = "shown";
            }
        }

        states: State {
            name: "shown"
        }

        function closeAndSwitchToTab(index) {
            recentView.reset()
            internal.switchToTab(index, false)
        }

        Keys.onEscapePressed: closeAndSwitchToTab(0)

        TabsList {
            id: tabslist
            anchors.fill: parent
            model: tabsModel
            readonly property real delegateMinHeight: units.gu(20)
            delegateHeight: {
                if (recentView.state == "shown") {
                    return Math.max(height / 3, delegateMinHeight)
                } else if (bottomEdgeHandle.stage == 0) {
                    return height
                } else if (bottomEdgeHandle.stage == 1) {
                    return (1 - 1.8 * bottomEdgeHandle.dragFraction) * height
                } else if (bottomEdgeHandle.stage >= 2) {
                    return Math.max(height / 3, delegateMinHeight)
                } else {
                    return delegateMinHeight
                }
            }
            chromeHeight: chrome.height
            onScheduleTabSwitch: {
                chrome.hidden = false
                internal.nextTabIndex = index
            }
            onTabSelected: recentView.closeAndSwitchToTab(index)
            onTabClosed: internal.closeTab(index)
        }

        Local.Toolbar {
            id: recentToolbar
            objectName: "recentToolbar"

            anchors {
                left: parent.left
                right: parent.right
            }
            height: units.gu(7)
            state: "hidden"

            color: browser.incognito ? theme.palette.normal.base : theme.palette.normal.foreground

            Button {
                objectName: "doneButton"
                anchors {
                    left: parent.left
                    leftMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                text: i18n.tr("Done")

                onClicked: recentView.closeAndSwitchToTab(0)
            }
            
            Row {
                id: rightActionsRow

                spacing: units.gu(2)
                height: parent.height - units.gu(2)

                anchors {
                    right: parent.right
                    rightMargin: units.gu(2)
                    verticalCenter: parent.verticalCenter
                }

                ToolbarAction {
                    objectName: "reopenTabButton"
                    visible: !incognito && internal.closedTabHistory.length > 0
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                    }

                    text: i18n.tr("Reopen Tab")

                    iconName: "undo"
                    color: theme.palette.normal.foregroundText

                    onClicked: {
                        recentView.reset()
                        internal.undoCloseTab()
                    }
                }

                ToolbarAction {
                    objectName: "newTabButton"
                    anchors {
                        top: parent.top
                        bottom: parent.bottom
                    }

                    text: i18n.tr("New Tab")

                    iconName: browser.incognito ? "private-tab-new" : "add"
                    color: theme.palette.normal.foregroundText

                    onClicked: {
                        recentView.reset()
                        internal.openUrlInNewTab("", true)
                    }
                }
            }
        }

        function reset() {
            state = ""
            recentToolbar.state = "hidden"
            tabslist.reset()
            internal.resetFocus()
        }
    }

    SearchEngine {
        id: currentSearchEngine
        searchPaths: searchEnginesSearchPaths
        filename: settings.searchEngine
    }

    Chrome {
        id: chrome

        tab: internal.nextTab || tabsModel.currentTab
        tabsModel: browser.tabsModel
        searchUrl: currentSearchEngine.urlTemplate

        incognito: browser.incognito

        showTabsBar: browser.wide
        showFaviconInAddressBar: !browser.wide

        thisWindow: browser.thisWindow
        windowFactory: browser.windowFactory

        availableHeight: tabContainer.height - (bottomEdgeHandle.enabled ? bottomEdgeHandle.height : 0)

        touchEnabled: internal.hasTouchScreen

        tabsBarDimmed: dropAreaTopCover.containsDrag || dropAreaBottomCover.containsDrag
        tabListMode: recentView.visible

        property bool hidden: false

        Behavior on y {
            NumberAnimation {
                from: -chrome.height + invisibleTabChrome.height
                duration: UbuntuAnimation.FastDuration
            }
        }

        function isCurrentUrlBookmarked() {
            return tab ? BookmarksModel.contains(tab.url) : false
        }
        bookmarked: isCurrentUrlBookmarked()
        onCloseTabRequested: internal.closeCurrentTab()
        onToggleBookmark: {
            if (isCurrentUrlBookmarked()) BookmarksModel.remove(tab.url)
            // QtWebEngine icons are provided as e.g. image://favicon/https://duckduckgo.com/favicon.ico
            else internal.addBookmark(tab.url, tab.title, (UrlUtils.schemeIs(tab.icon, "image") && UrlUtils.hostIs(tab.icon, "favicon")) ? tab.icon.toString().substring(("image://favicon/").length) : tab.icon)
        }
        onToggleDownloads: {
            internal.showDownloadsDialog()
        }
        onWebviewChanged: bookmarked = isCurrentUrlBookmarked()
        Connections {
            target: chrome.tab
            onUrlChanged: chrome.bookmarked = chrome.isCurrentUrlBookmarked()
        }
        Connections {
            target: BookmarksModel
            onCountChanged: chrome.bookmarked = chrome.isCurrentUrlBookmarked()
        }

        onSwitchToTab: internal.switchToTab(index, true)
        onRequestNewTab: internal.openUrlInNewTab("", makeCurrent, true, index)
        onTabClosed: internal.closeTab(index, moving)

        onFindInPageModeChanged: {
            if (!chrome.findInPageMode) internal.resetFocus()
            else chrome.forceActiveFocus()
        }

        anchors {
            left: parent.left
            right: parent.right
        }

        drawerActions: [
            Action {
                objectName: "newwindow"
                text: i18n.tr("New window")
                iconName: "browser-tabs"
                onTriggered: browser.newWindowRequested(false)
            },
            Action {
                objectName: "newprivatewindow"
                text: i18n.tr("New private window")
                iconName: "private-browsing"
                onTriggered: browser.newWindowRequested(true)
            },
            Action {
                objectName: "share"
                text: i18n.tr("Share")
                iconName: "share"
                enabled: (contentHandlerLoader.status == Loader.Ready) &&
                         chrome.tab && chrome.tab.url.toString()
                onTriggered: internal.shareLink(chrome.tab.url, chrome.tab.title)
            },
            Action {
                objectName: "bookmarks"
                text: i18n.tr("Bookmarks")
                iconName: "bookmark"
                onTriggered: bookmarksViewLoader.active = true
            },
            Action {
                objectName: "history"
                text: i18n.tr("History")
                iconName: "history"
                onTriggered: historyViewLoader.active = true
            },
            Action {
                objectName: "findinpage"
                text: i18n.tr("Find in page")
                iconName: "search"
                enabled: !chrome.findInPageMode && !newTabViewLoader.active
                onTriggered: chrome.findInPageMode = true
            },
            Action {
                objectName: "downloads"
                text: i18n.tr("Downloads")
                iconName: "save-to"
                enabled: contentHandlerLoader.status == Loader.Ready
                onTriggered: downloadsViewLoader.active = true
            },
            Action {
                objectName: "settings"
                text: i18n.tr("Settings")
                iconName: "settings"
                onTriggered: settingsViewLoader.active = true
            },
            Action {
                objectName: "view source"
                text: i18n.tr("View source")
                iconName: "text-xml-symbolic"
                enabled: currentWebview && (currentWebview.url.toString() !== "") && (currentWebview.url.toString().substring(0,12) !== "view-source:")
                onTriggered: {
                    var currentUrl = currentWebview.url;
                    if (UrlUtils.isPdfViewerExtensionUrl(currentWebview.url)) {
                        currentUrl = currentWebview.url.toString().substr(UrlUtils.getPdfViewerExtensionUrlPrefix().length);
                    }
                    openLinkInNewTabRequested("view-source:%1".arg(currentUrl), false);
                }
            },
            Action {
                objectName: "save"
                text: i18n.tr("Save / Print to PDF")
                iconName: "save-as"
                enabled: currentWebview && (currentWebview.url.toString() !== "")
                onTriggered: {
                    currentWebview.runJavaScript("document.contentType", function(docContentType) {
                        var savePageDialog = PopupUtils.open(Qt.resolvedUrl("../SavePageDialog.qml"), currentWebview);
                        savePageDialog.saveAsHtml.connect( function() { currentWebview.triggerWebAction(WebEngineView.SavePage);});
                        savePageDialog.canSaveAsHtml = (docContentType.indexOf("text/") === 0) && ! UrlUtils.isPdfViewerExtensionUrl(currentWebview.url);

                        savePageDialog.download.connect( function() {currentWebview.runJavaScript("var link = document.createElement('a');link.download='';link.href='%1';link.click();".arg(UrlUtils.isPdfViewerExtensionUrl(currentWebview.url) ? currentWebview.url.toString().substr(UrlUtils.getPdfViewerExtensionUrlPrefix().length) : currentWebview.url));});
                        savePageDialog.canDownload = (docContentType !== "text/html") || (UrlUtils.isPdfViewerExtensionUrl(currentWebview.url) && ! currentWebview.url.toString().substr(UrlUtils.getPdfViewerExtensionUrlPrefix().length).indexOf("file://%1".arg(currentWebview.profile.downloadPath)) === 0);

                        // the filename of the PDF is determined from the title (replace not allowed / problematic chars with '_')
                        // the QtWebEngine does give the filename (.mhtml) for the SavePage action with that pattern as well
                        savePageDialog.saveAsPdf.connect( function() { currentWebview.printToPdf("%1/pdf_tmp/%2.pdf".arg(cacheLocation).arg(currentWebview.title.replace(/["/:*?\\<>|~]/g,'_')));});
                        savePageDialog.canSaveAsPdf = ((docContentType.indexOf("text/") === 0) || (docContentType.indexOf("image/") === 0)) && ! UrlUtils.isPdfViewerExtensionUrl(currentWebview.url);
                    });
                }
            },
            Action {
                objectName: "zoom"
                text: i18n.tr("Zoom")
                iconName: "zoom-in"
                enabled: currentWebview && (currentWebview.url.toString() !== "")
                onTriggered: currentWebview.showZoomMenu()
            }

        ]

        canSimplifyText: !browser.wide
        editing: activeFocus || suggestionsList.activeFocus

        Keys.onDownPressed: {
            if (suggestionsList.count) suggestionsList.focus = true
            else if (!incognito && (newTabViewLoader.status == Loader.Ready)) {
                newTabViewLoader.forceActiveFocus()
            }
        }

        Keys.onEscapePressed: {
            if (chrome.findInPageMode) {
                chrome.findInPageMode = false
            } else {
                internal.resetFocus()
            }
        }

        Connections {
            target: browser.currentWebview
            onLoadingChanged: {
                if (browser.currentWebview.loading && !recentView.visible) {
                    chrome.state = "shown";
                } else if (browser.currentWebview.isFullScreen) {
                    chrome.state = "hidden"
                }
            }
            onIsFullScreenChanged: {
                if (browser.currentWebview.isFullScreen) {
                    chrome.state = "hidden";
                } else {
                    chrome.state = "shown";
                }
            }
        }
    }

    Common.ChromeStateTracker {
        webview: browser.currentWebview
        header: chrome
     }

    Suggestions {
        id: suggestionsList
        opacity: ((chrome.state === "shown") && (activeFocus || chrome.activeFocus) &&
                  (count > 0) && !chrome.drawerOpen && !chrome.findInPageMode && !chrome.contextMenuVisible) ? 1.0 : 0.0
        Behavior on opacity {
            UbuntuNumberAnimation {}
        }
        enabled: opacity > 0
        anchors {
            top: chrome.bottom
            horizontalCenter: parent.horizontalCenter
        }
        width: chrome.width - units.gu(5)
        height: enabled ? Math.min(contentHeight, tabContainer.height - chrome.height - units.gu(2)) : 0

        searchTerms: chrome.text.split(/\s+/g).filter(function(term) { return term.length > 0 })

        Keys.onUpPressed: chrome.focus = true
        Keys.onEscapePressed: internal.resetFocus()

        models: searchTerms && searchTerms.length > 0 ?
                [historySuggestions,
                 bookmarksSuggestions,
                 searchSuggestions.limit(4)] : []

        LimitProxyModel {
            id: historySuggestions
            limit: 2
            readonly property string icon: "history"
            readonly property bool displayUrl: true
            sourceModel: TextSearchFilterModel {
                sourceModel: HistoryModel
                terms: suggestionsList.searchTerms
                searchFields: ["url", "title"]
            }
        }

        LimitProxyModel {
            id: bookmarksSuggestions
            limit: 2
            readonly property string icon: "non-starred"
            readonly property bool displayUrl: true
            sourceModel: TextSearchFilterModel {
                sourceModel: BookmarksModel
                terms: suggestionsList.searchTerms
                searchFields: ["url", "title"]
            }
        }

        SearchSuggestions {
            id: searchSuggestions
            terms: suggestionsList.searchTerms
            searchEngine: currentSearchEngine
            active: (chrome.activeFocus || suggestionsList.activeFocus) &&
                     !browser.incognito && !chrome.findInPageMode &&
                     !UrlUtils.looksLikeAUrl(chrome.text.replace(/ /g, "+"))

            function limit(number) {
                var slice = results.slice(0, number)
                slice.icon = 'search'
                slice.displayUrl = false
                return slice
            }
        }

        onActivated: {
            browser.currentWebview.url = url
            tabContainer.forceActiveFocus()
            chrome.requestedUrl = url
        }
    }

    onWideChanged: {
        if (wide) {
            recentView.reset()
        } else {
            // In narrow mode, the tabslist is a stack: the current tab is always at the top.
            tabsModel.move(tabsModel.currentIndex, 0)
        }
    }

    BottomEdgeHandle {
        id: bottomEdgeHandle
        objectName: "bottomEdgeHandle"

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: units.gu(2)

        enabled: !browser.wide && (recentView.state == "") &&
                 browser.currentWebview &&
                 (Screen.orientation == Screen.primaryOrientation)

        onDraggingChanged: {
            if (dragging) {
                if (browser.thisWindow) {
                    browser.thisWindow.setFullscreen(false)
                }
            } else {
                if (stage == 1) {
                    if (tabsModel.count > 1) {
                        tabslist.selectAndAnimateTab(1)
                    } else {
                        recentView.state = "shown"
                        recentToolbar.state = "shown"
                    }
                } else if (stage == 2) {
                    recentView.state = "shown"
                    recentToolbar.state = "shown"
                } else if (stage >= 3) {
                    recentView.state = "shown"
                    recentToolbar.state = "shown"
                }
            }
        }
    }

    Rectangle {
        id: bottomEdgeHint
        color: theme.palette.normal.background
        border.color: (color.hslLightness > 0.5) ? Qt.darker(color, 1.05) : Qt.lighter(color, 1.5)
        radius: units.gu(1.5)
        height: units.gu(4)
        width: units.gu(10)
        property bool forceShow: false
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: (((chrome.state == "shown") && browser.currentWebview && !browser.currentWebview.fullscreen) || forceShow) ? -height / 2 : -height
            Behavior on bottomMargin {
                UbuntuNumberAnimation {}
            }
        }
        visible: bottomEdgeHandle.enabled && !internal.hasMouse
        opacity: recentView.visible ? 0 : 1
        Behavior on opacity {
            UbuntuNumberAnimation {}
        }
        Label {
            anchors {
                horizontalCenter: parent.horizontalCenter
                verticalCenterOffset: units.dp(2)
            }
            fontSize: "small"
            color: theme.palette.normal.backgroundText
            // TRANSLATORS: %1 refers to the current number of tabs opened
            text: i18n.tr("(%1)").arg(tabsModel ? tabsModel.count : 0)
        }
    }

    MouseArea {
        id: bottomEdgeBar
        objectName: "bottomEdgeBar"
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        enabled: !browser.wide && internal.hasMouse &&
                 (osk.state == "hidden") && (recentView.state == "")
        visible: enabled
        height: visible ? units.gu(4) : 0
        // Ensure that this ends up below the chrome, so that the
        // drawer menu’s inverse mouse area covers it.
        z: -1

        onClicked: {
            recentView.state = "shown"
            recentToolbar.state = "shown"
        }

        Rectangle {
            anchors.fill: parent
            color: theme.palette.normal.foreground
            border {
                width: units.dp(1)
                color: theme.palette.normal.base
            }
        }

        Label {
            anchors.centerIn: parent
            color: theme.palette.normal.overlayText
            // TRANSLATORS: %1 refers to the current number of tabs opened
            text: i18n.tr("(%1)").arg(tabsModel ? tabsModel.count : 0)
        }
    }

    Loader {
        id: bookmarksViewLoader

        anchors.fill: parent
        active: false
        asynchronous: true
        Connections {
            target: browser
            onWideChanged: bookmarksViewLoader.selectBookmarksView()
        }
        Component.onCompleted: bookmarksViewLoader.selectBookmarksView()

        function selectBookmarksView() {
            bookmarksViewLoader.setSource(browser.wide ? "BookmarksViewWide.qml" : "BookmarksView.qml",
                                          {"focus": true,
                                           "homepageUrl": Qt.binding(function () {return settings.homepage})
            });
        }

        onStatusChanged: {
            if (status == Loader.Ready) {
                chrome.findInPageMode = false
                forceActiveFocus()
            } else {
                internal.resetFocus()
            }
        }

        Connections {
            target: bookmarksViewLoader.item

            onBookmarkEntryClicked: {
                internal.openUrlInNewTab(url, true)
                bookmarksViewLoader.active = false
            }
            onBack: bookmarksViewLoader.active = false
            onNewTabClicked: {
                internal.openUrlInNewTab("", true)
                bookmarksViewLoader.active = false
            }
        }
    }

    Loader {
        id: historyViewLoader

        anchors.fill: parent
        active: false
        asynchronous: true
        Connections {
            target: browser
            onWideChanged: historyViewLoader.selectHistoryView()
        }
        Component.onCompleted: historyViewLoader.selectHistoryView()

        function selectHistoryView() {
            historyViewLoader.setSource(browser.wide ? "HistoryViewWide.qml" : "HistoryViewWithExpansion.qml",
                                        {"focus": true});
        }

        Connections {
            target: historyViewLoader.item
            onHistoryEntryClicked: {
                historyViewLoader.active = false
                internal.openUrlInNewTab(url, true)
            }
            onNewTabRequested: {
                historyViewLoader.active = false
                internal.openUrlInNewTab("", true)
            }
            onDone: {
                historyViewLoader.active = false
                internal.resetFocus()
            }
            onBack: historyViewLoader.active = false
        }

        onStatusChanged: {
            if (status == Loader.Ready) {
                chrome.findInPageMode = false
                forceActiveFocus()
                historyViewLoader.item.loadModel()
            } else {
                internal.resetFocus()
            }
        }
    }

    Loader {
        id: settingsViewLoader

        anchors.fill: parent
        active: false
        asynchronous: true

        onStatusChanged: {
            if (status == Loader.Ready) {
                chrome.findInPageMode = false
                forceActiveFocus()
            } else {
                internal.resetFocus()
            }
        }

        Component.onCompleted: setSource("SettingsPage.qml", {
                                             "focus": true,
                                             "settingsObject": settings
                                         })
        Connections {
            target: settingsViewLoader.item
            onClearCache: {
                // clear Http cache
                SharedWebContext.sharedContext.clearHttpCache();
                SharedWebContext.sharedIncognitoContext.clearHttpCache();

                var cacheLocationUrl = Qt.resolvedUrl(cacheLocation);
                var dataLocationUrl = Qt.resolvedUrl(dataLocation);

                // clear favicons
                FileOperations.removeDirRecursively(cacheLocationUrl + "/favicons");

                // remove captures
                FileOperations.removeDirRecursively(cacheLocationUrl + "/captures");

                // Application Cache
                FileOperations.removeDirRecursively(dataLocationUrl + "/Application Cache");

                // File System
                FileOperations.removeDirRecursively(dataLocationUrl + "/File System");

                // Local Storage
                FileOperations.removeDirRecursively(dataLocationUrl + "/Local Storage");

                // Service WorkerScript
                FileOperations.removeDirRecursively(dataLocationUrl + "/Service Worker");

                // Visited Links
                FileOperations.remove(dataLocationUrl + "/Visited Links");
            }
            onClearAllCookies: {

                BrowserUtils.deleteAllCookiesOfProfile(SharedWebContext.sharedContext);
                BrowserUtils.deleteAllCookiesOfProfile(SharedWebContext.sharedIncognitoContext);
            }
            onDone: settingsViewLoader.active = false
        }
    }

    Loader {
        id: downloadsViewLoader

        anchors.fill: parent
        active: false
        asynchronous: true
        Component.onCompleted: {
            setSource("../DownloadsPage.qml", {
                          "incognito": incognito,
                          "focus": true
            })
        }

        function loadSynchronously() {
            // temporarily set asynchronous to false
            asynchronous = false;
            active = true;
            asynchronous = true;
        }

        Connections {
            target: downloadsViewLoader.item
            onDone: downloadsViewLoader.active = false
            onPreview: {
                    downloadsViewLoader.active = false
                    currentWebview.url = url;
            }
        }

        onStatusChanged: {
            if (status == Loader.Ready) {
                forceActiveFocus()
            } else {
                internal.resetFocus()
            }
        }
    }

    property Component tabComponent
    Loader {
        source: "TabComponent.qml"
        onLoaded: tabComponent = item
    }

    QtObject {
        id: internal
        property var closedTabHistory: []

        property int nextTabIndex: -1
        readonly property var nextTab: (nextTabIndex > -1) ? tabsModel.get(nextTabIndex) : null
        onNextTabChanged: {
            if (nextTab) {
                nextTab.aboutToShow()
            }
        }

        readonly property bool hasMouse: (miceModel.count + touchPadModel.count) > 0
        readonly property bool hasTouchScreen: touchScreenModel.count > 0

        // Ref: https://code.google.com/p/chromium/codesearch#chromium/src/components/ui/zoom/page_zoom_constants.cc
        //readonly property var zoomFactors: [0.25, 0.333, 0.5, 0.666, 0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0]

        function instantiateShareComponent() {
            var component = Qt.createComponent("../Share.qml")
            if (component.status === Component.Ready) {
                var share = component.createObject(browser)
                share.onDone.connect(share.destroy)
                return share
            }
            return null
        }

        function shareLink(url, title) {
            var share = instantiateShareComponent()
            if (share) share.shareLink(url, title)
        }

        function shareText(text) {
            var share = instantiateShareComponent()
            if (share) share.shareText(text)
        }

        function openUrlInNewTab(url, setCurrent, load, index) {
            load = typeof load !== 'undefined' ? load : true
            var tab = internal.createTabHelper({"initialUrl": url})
            addTab(tab, setCurrent, index)
            if (load) {
                tab.load()
            }
            if (!url.toString()) {
                focusAddressBar()
            }
        }

        function addTab(tab, setCurrent, index) {
            if (index === undefined) index = tabsModel.add(tab)
            else index = tabsModel.insert(tab, index)
            if (setCurrent) {
                chrome.requestedUrl = tab.initialUrl
                switchToTab(index, true)
            }
        }

        function buildContextProperties(properties) {
            if (properties === undefined) {
                properties = {};
            }

            properties["bottomEdgeHandle"] = bottomEdgeHandle;
            properties["browser"] = browser;
            properties["chrome"] = chrome;
            properties["contentHandlerLoader"] = contentHandlerLoader;
            properties["downloadDialogLoader"] = downloadDialogLoader;
            properties["downloadsViewLoader"] = downloadsViewLoader;
            //properties["filePickerLoader"] = filePickerLoader;
            properties["internal"] = internal;
            properties["recentView"] = recentView;
            properties["tabsModel"] = tabsModel;

            return properties;
        }

        function createTabHelper(properties) {
            return Reparenter.createObject(tabComponent, tabContainer, internal.buildContextProperties(properties));
        }

        function closeTab(index, moving) {
            moving = moving === undefined ? false : moving;

            var tab = tabsModel.get(index)
            tabsModel.remove(index)

            if (tab) {
                if (!incognito && tab.url.toString().length > 0) {
                    
                    // For triggering property change on closedTabHistory
                    var temp = closedTabHistory.slice()
                    temp.push({
                        state: serializeTabState(tab),
                        index: index
                    })
                    closedTabHistory = temp.slice()
                }

                // When moving a tab between windows don't close the tab as it has been moved
                if (!moving) {
                    tab.close()
                }
            }
            if (tabsModel.currentTab) {
                tabsModel.currentTab.load()
            }
            if (tabsModel.count === 0) {
                internal.openUrlInNewTab("", true)
                recentView.reset()
            }
        }

        function closeCurrentTab() {
            if (tabsModel.count > 0) {
                closeTab(tabsModel.currentIndex)
            }
        }

        function closeTabsWithUrl(url) {
            var i;
            for (i = 0; i < tabsModel.count; i++) {
                if (tabsModel.get(i).url === url)
                    closeTab(i);
            }
        }

        function undoCloseTab() {
            if (!incognito && closedTabHistory.length > 0) {
                // For triggering property change on closedTabHistory
                var temp = closedTabHistory.slice()
                var tabInfo = temp.pop()
                closedTabHistory = temp.slice()
                var tab = restoreTabState(tabInfo.state)
                addTab(tab, true, tabInfo.index)
                tab.load()
            }
        }

        function switchToPreviousTab() {
            if (browser.wide) {
                internal.switchToTab((tabsModel.currentIndex - 1 + tabsModel.count) % tabsModel.count, true)
            } else {
                internal.switchToTab(tabsModel.count - 1, true)
            }
        }

        function switchToNextTab() {
            if (browser.wide) {
                internal.switchToTab((tabsModel.currentIndex + 1) % tabsModel.count, true)
            } else {
                internal.switchToTab(tabsModel.count - 1, true)
            }
        }

        function switchToTab(index, delayed) {
            if (delayed) {
                nextTabIndex = index
                delayedTabSwitcher.restart()
            } else {
                tabsModel.currentIndex = index
                nextTabIndex = -1
                var tab = tabsModel.currentTab
                if (recentView.visible) {
                    recentView.focus = true
                } else if (tab) {
                    if (tab.empty) {
                        focusAddressBar()
                    } else {
                        tabContainer.forceActiveFocus()
                        tab.load();
                    }
                }
            }
        }

        function focusAddressBar(selectContent) {
            chrome.forceActiveFocus()
            Qt.inputMethod.show() // work around http://pad.lv/1316057
            if (selectContent) chrome.selectAll()
        }

        function resetFocus() {
            var currentTab = tabsModel.currentTab;
            if (currentTab) {
                if (currentTab.empty) {
                    internal.focusAddressBar()
                } else {
                    contentsContainer.focus = true;
                }
            }
        }

        // Invalid certificates the user has explicitly allowed for this session
        property var allowedCertificateErrors: []

        function allowCertificateError(error) {
            var host = UrlUtils.extractHost(error.url)
            var code = error.certError
            var fingerprint = error.certificate.fingerprintSHA1
            allowedCertificateErrors.push([host, code, fingerprint])
        }

        function isCertificateErrorAllowed(error) {
            var host = UrlUtils.extractHost(error.url)
            var code = error.certError
            var fingerprint = error.certificate.fingerprintSHA1
            for (var i in allowedCertificateErrors) {
                var allowed = allowedCertificateErrors[i]
                if ((host === allowed[0]) &&
                    (code === allowed[1]) &&
                    (fingerprint === allowed[2])) {
                    return true
                }
            }
            return false
        }

        // domains the user has allowed custom protocols for this (incognito) session
        property var domainsWithCustomUrlSchemesAllowed: []

        function allowCustomUrlSchemes(domain, allowPermanently) {
           domainsWithCustomUrlSchemesAllowed.push(domain);

           if (allowPermanently)
           {
                DomainSettingsModel.allowCustomUrlSchemes(domain, true);
           }
        }

        function areCustomUrlSchemesAllowed(domain) {

            for (var i in domainsWithCustomUrlSchemesAllowed) {
                if (domain === domainsWithCustomUrlSchemesAllowed[i]) {
                    return true;
                }
            }

            if (DomainSettingsModel.areCustomUrlSchemesAllowed(domain))
            {
                domainsWithCustomUrlSchemesAllowed.push(domain);
                return true;
            }

            return false;
        }

        function historyGoBack() {
            if (currentWebview && currentWebview.canGoBack) {
                internal.resetFocus()
                currentWebview.goBack()
            }
        }

        function historyGoForward() {
            if (currentWebview && currentWebview.canGoForward) {
                internal.resetFocus()
                currentWebview.goForward()
            }
        }

        function navigateToUrlAsync(targetUrl)
        {
            currentWebview.runJavaScript("window.location.href = '%1';".arg(targetUrl));
        }

        property var currentBookmarkOptionsDialog: null
        function addBookmark(url, title, icon, location) {
            if (title === "") title = UrlUtils.removeScheme(url)
            BookmarksModel.add(url, title, icon, "")
            if (location === undefined) location = chrome.bookmarkTogglePlaceHolder
            var properties = {"bookmarkUrl": url, "bookmarkTitle": title}
            internal.currentBookmarkOptionsDialog = PopupUtils.open(Qt.resolvedUrl("BookmarkOptions.qml"),
                                                           location, properties)
        }
        
        property var recentDownloads: []
        property var currentDownloadsDialog: null
        function showDownloadsDialog(caller) {
            if (!internal.currentDownloadsDialog) {
                chrome.downloadNotify = false
                if (caller === undefined) caller = chrome.downloadsButtonPlaceHolder
                var properties = {"downloadsList": recentDownloads}

                internal.currentDownloadsDialog = PopupUtils.open(Qt.resolvedUrl("../DownloadsDialog.qml"),
                                                               caller, properties)
           }
        }

        function addNewDownload(download) {
            recentDownloads.unshift(download)
            chrome.showDownloadButton = Qt.binding(
                                        function(){
                                            if (browser.wide) {
                                                return true;
                                            } else {
                                                if (internal.currentDownloadsDialog) {
                                                    if (internal.currentDownloadsDialog.isEmpty) {
                                                        return false;
                                                    } else {
                                                        return true;
                                                    }
                                                } else {
                                                    if (recentDownloads.length > 0) {
                                                        return true;
                                                    } else {
                                                        return false;
                                                    }
                                                }
                                            }
                                        })
            if (internal.currentDownloadsDialog) {
                internal.currentDownloadsDialog.downloadsList = recentDownloads
            }
        }
    }

    Connections {
        target: internal.currentDownloadsDialog

        onShowDownloadsPage: showDownloadsPage()

        onPreview: {
                    PopupUtils.close(internal.currentDownloadsDialog);
                    currentWebview.url = url;
        }
    }

    // Work around https://launchpad.net/bugs/1502675 by delaying the switch to
    // the next tab for a fraction of a second to avoid a black flash.
    Timer {
        id: delayedTabSwitcher
        interval: 50
        onTriggered: internal.switchToTab(internal.nextTabIndex, false)
    }

    Connections {
        target: tabsModel
        onCurrentTabChanged: {
            chrome.findInPageMode = false
            internal.resetFocus()
        }
    }

    // TODO: internationalize non-standard key sequences?

    // Ctrl+Tab or Ctrl+PageDown: cycle through open tabs
    Shortcut {
        sequence: StandardKey.NextChild
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.switchToNextTab()
    }
    Shortcut {
        sequence: "Ctrl+PgDown"
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.switchToNextTab()
    }

    // Ctrl+Shift+Tab or Ctrl+PageUp: cycle through open tabs in reverse order
    Shortcut {
        sequence: StandardKey.PreviousChild
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.switchToPreviousTab()
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.switchToPreviousTab()
    }
    Shortcut {
        sequence: "Ctrl+PgUp"
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.switchToPreviousTab()
    }

    // Ctrl+W or Ctrl+F4: Close the current tab
    Shortcut {
        sequence: StandardKey.Close
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.closeCurrentTab()
    }
    Shortcut {
        sequence: "Ctrl+F4"
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.closeCurrentTab()
    }

    // Ctrl+Shift+W or Ctrl+Shift+T: Undo close tab
    Shortcut {
        sequence: "Ctrl+Shift+W"
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.undoCloseTab()
    }
    Shortcut {
        sequence: "Ctrl+Shift+T"
        enabled: contentsContainer.visible || recentView.visible
        onActivated: internal.undoCloseTab()
    }

    // Ctrl+T: Open a new Tab
    Shortcut {
        sequence: StandardKey.AddTab
        enabled: contentsContainer.visible || recentView.visible ||
                 bookmarksViewLoader.active || historyViewLoader.active
        onActivated: {
            internal.openUrlInNewTab("", true)
            if (recentView.visible) recentView.reset()
            bookmarksViewLoader.active = false
            historyViewLoader.active = false
        }
    }

    // F6 or Ctrl+L or Alt+D: Select the content in the address bar
    Shortcut {
        sequence: "F6"
        enabled: contentsContainer.visible
        onActivated: internal.focusAddressBar(true)
    }
    Shortcut {
        sequence: "Ctrl+L"
        enabled: contentsContainer.visible
        onActivated: internal.focusAddressBar(true)
    }
    Shortcut {
        sequence: "Alt+D"
        enabled: contentsContainer.visible
        onActivated: internal.focusAddressBar(true)
    }

    // Ctrl+D: Toggle bookmarked state on current Tab
    Shortcut {
        sequence: "Ctrl+D"
        enabled: contentsContainer.visible && !newTabViewLoader.active
        onActivated: {
            if (internal.currentBookmarkOptionsDialog) {
                internal.currentBookmarkOptionsDialog.hide()
            } else if (currentWebview) {
                if (BookmarksModel.contains(currentWebview.url)) {
                    BookmarksModel.remove(currentWebview.url)
                } else {
                    internal.addBookmark(currentWebview.url, currentWebview.title, currentWebview.icon)
                }
            }
        }
    }

    // Ctrl+H: Show History
    Shortcut {
        sequence: "Ctrl+H"
        enabled: contentsContainer.visible
        onActivated: historyViewLoader.active = true
    }

    // Ctrl+Shift+O: Show Bookmarks
    Shortcut {
        sequence: "Ctrl+Shift+O"
        enabled: contentsContainer.visible
        onActivated: bookmarksViewLoader.active = true
    }

    // Alt+← or Backspace: Goes to the previous page in history
    Shortcut {
        sequence: StandardKey.Back
        enabled: contentsContainer.visible
        onActivated: internal.historyGoBack()
    }

    // Alt+→ or Shift+Backspace: Goes to the next page in history
    Shortcut {
        sequence: StandardKey.Forward
        enabled: contentsContainer.visible
        onActivated: internal.historyGoForward()
    }

    // F5 or Ctrl+R: Reload current Tab
    Shortcut {
        sequence: "Ctrl+R"
        enabled: contentsContainer.visible
        onActivated: if (currentWebview) currentWebview.reload()
    }
    Shortcut {
        sequence: "F5"
        enabled: contentsContainer.visible
        onActivated: if (currentWebview) currentWebview.reload()
    }

    // Ctrl+F: Find in Page
    Shortcut {
        sequence: StandardKey.Find
        enabled: contentsContainer.visible && !newTabViewLoader.active
        onActivated: chrome.findInPageMode = true
    }

    // Ctrl+J: Show downloads page
    Shortcut {
        sequence: "Ctrl+J"
        enabled: chrome.visible &&
                 contentHandlerLoader.status == Loader.Ready &&
                 !downloadsViewLoader.active
        onActivated: downloadsViewLoader.active = true
    }

    // Ctrl+G: Find next
    Shortcut {
        sequence: StandardKey.FindNext
        enabled: currentWebview && chrome.findInPageMode
        onActivated: currentWebview.findController.next()
    }

    // Ctrl+Shift+G: Find previous
    Shortcut {
        sequence: StandardKey.FindPrevious
        enabled: currentWebview && chrome.findInPageMode
        onActivated: currentWebview.findController.previous()
    }

    // Ctrl+Plus: zoom in
    Shortcut {
        sequence: StandardKey.ZoomIn
        enabled: currentWebview
        onActivated: currentWebview.zoomController.zoomIn()
    }
    // For improved compatibility with qwerty-based keyboard layouts, where "="
    // and "+" are on the same key (see https://launchpad.net/bugs/1624381):
    Shortcut {
        sequence: "Ctrl+="
        enabled: currentWebview
        onActivated: currentWebview.zoomController.zoomIn()
    }

    // Ctrl+Minus: zoom out
    Shortcut {
        sequence: StandardKey.ZoomOut
        enabled: currentWebview
        onActivated: currentWebview.zoomController.zoomOut()
    }
    // For improved compatibility with qwerty-based keyboard layouts, where "-"
    // and "_" are on the same key (see https://launchpad.net/bugs/1624381):
    Shortcut {
        sequence: "Ctrl+_"
        enabled: currentWebview
        onActivated: currentWebview.zoomController.zoomOut()
    }

    // Ctrl+0: reset zoom factor to default
    Shortcut {
        sequence: "Ctrl+0"
        enabled: currentWebview
        onActivated: currentWebview.zoomController.resetSaveFit()
    }

    Loader {
        id: contentHandlerLoader
        source: "../ContentHandler.qml"
        asynchronous: true
    }

    Connections {
        target: contentHandlerLoader.item
        onExportFromDownloads: {
            downloadsViewLoader.loadSynchronously();
            // export from downloads
            downloadsViewLoader.item.mimetypeFilter = mimetypeFilter
            downloadsViewLoader.item.activeTransfer = transfer
            downloadsViewLoader.item.multiSelect = multiSelect
            downloadsViewLoader.item.pickingMode = true
        }
    }

    Loader {
        id: downloadDialogLoader
        source: "ContentDownloadDialog.qml"
        asynchronous: true
    }

    function showDownloadsPage() {
        downloadsViewLoader.active = true
        return downloadsViewLoader.item
    }

    function startDownload(download) {

        var downloadIdDataBase = Common.ActiveDownloadsSingleton.downloadIdPrefixOfCurrentSession.concat(download.id)

        // check if the ID has already been added
        if ( Common.ActiveDownloadsSingleton.currentDownloads[downloadIdDataBase] === download )
        {
           console.log("the download id " + downloadIdDataBase + " has already been added.")
           return
        }

        console.log("adding download with id " + downloadIdDataBase)
        Common.ActiveDownloadsSingleton.currentDownloads[downloadIdDataBase] = download
        DownloadsModel.add(downloadIdDataBase, (download.url.toString().indexOf("file://%1/pdf_tmp".arg(cacheLocation)) === 0) ? "" : download.url, download.path, download.mimeType, incognito)

        internal.addNewDownload(download)
        internal.showDownloadsDialog()
    }

    function setDownloadComplete(download) {

        var downloadIdDataBase = Common.ActiveDownloadsSingleton.downloadIdPrefixOfCurrentSession.concat(download.id)

        if ( Common.ActiveDownloadsSingleton.currentDownloads[downloadIdDataBase] !== download )
        {
            console.log("the download id " + downloadIdDataBase + " is not in the current downloads.")
            return
        }

        console.log("download with id " + downloadIdDataBase + " is complete.")

        DownloadsModel.setComplete(downloadIdDataBase, true)

        if ((download.state === WebEngineDownloadItem.DownloadCancelled) || (download.state === WebEngineDownloadItem.DownloadInterrupted))
        {
          DownloadsModel.setError(downloadIdDataBase, download.interruptReasonString)
        }

        if (!internal.currentDownloadsDialog) {
            chrome.downloadNotify = true
        }
    }

    Connections {

        target: currentWebview ? currentWebview.context : null

        onDownloadRequested: {

            if (currentWebview.url.toString().match(/^view-source:/i)) {
                console.log(incognito ? "a download was rejected" : "a download was rejected with url %1".arg(download.url));
                return;
            }

            // already downloaded item
            if ((download.url.toString().indexOf("file://%1".arg(currentWebview.profile.downloadPath)) === 0) && FileOperations.extension(download.path) !== "mhtml" ) {
               console.log(incognito ? "download rejected (item has already been downloaded)" : "download rejected (%1 has already been downloaded)".arg(download.url));
               currentWebview.showMessage(i18n.tr("the file is already in the downloads folder."))
               return;
            }

            console.log("a download was requested with path %1".arg(download.path))
            download.accept();
            browser.startDownload(download);
        }

        onDownloadFinished: {

            console.log(incognito? "download finished" : "a download was finished with path %1.".arg(download.path));
            browser.setDownloadComplete(download);

            // delete pdf in cache / close the tab
            if (download.url.toString().indexOf("file://%1/pdf_tmp".arg(cacheLocation)) === 0) {
              FileOperations.remove(download.url);
              internal.closeTabsWithUrl(download.url);
            }
        }
    }

    Connections {
        target: settings
        onZoomFactorChanged: DomainSettingsModel.defaultZoomFactor = settings.zoomFactor
        onDomainWhiteListModeChanged: DomainPermissionsModel.whiteListMode = settings.domainWhiteListMode
    }
    /*

    Loader {
        id: filePickerLoader
        source: "ContentPickerDialog.qml"
        asynchronous: true
    }

    */

    // Cover the webview (gaps around tabsbar) with DropArea so that webview doesn't steal events
    DropArea {
        id: dropAreaTopCover
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: units.gu(1)
        keys: ["webbrowser/tab-" + (incognito ? "incognito" : "public")]
        visible: chrome.showTabsBar

        onEntered: {
            window.raise()
            window.requestActivate()
        }
    }

    DropArea {
        id: dropAreaBottomCover
        anchors {
            fill: parent
            topMargin: chrome.tabsBarHeight
        }
        keys: ["webbrowser/tab-" + (incognito ? "incognito" : "public")]

        onEntered: {
            window.raise()
            window.requestActivate()
        }
    }
}
