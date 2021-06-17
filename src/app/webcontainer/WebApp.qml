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

import QtQuick 2.7
import QtWebEngine 1.10
import Qt.labs.settings 1.0
import webbrowsercommon.private 0.1
import Morph.Web 0.1
import Ubuntu.Components 1.3
import Ubuntu.Components.Popups 1.3
import Ubuntu.Unity.Action 1.1 as UnityActions
import "../actions" as Actions
import ".." as Common
import "ColorUtils.js" as ColorUtils

Common.BrowserView {
    id: webapp

    property Settings settings

    objectName: "webappBrowserView"

    currentWebview: containerWebView.currentWebview

    property alias window: containerWebView.window

    property alias url: containerWebView.url

    property bool accountSwitcher

    property string webappModelSearchPath: ""

    property var webappUrlPatterns
    property alias popupRedirectionUrlPrefixPattern: containerWebView.popupRedirectionUrlPrefixPattern
    property alias webviewOverrideFile: containerWebView.webviewOverrideFile
    property alias blockOpenExternalUrls: containerWebView.blockOpenExternalUrls
    property alias localUserAgentOverride: containerWebView.localUserAgentOverride
    property alias dataPath: containerWebView.dataPath
    property alias runningLocalApplication: containerWebView.runningLocalApplication
    property alias openExternalUrlInOverlay: containerWebView.openExternalUrlInOverlay
    property alias popupBlockerEnabled: containerWebView.popupBlockerEnabled

    property string webappName: ""

    property bool backForwardButtonsVisible: false
    property bool chromeVisible: false
    readonly property bool chromeless: !chromeVisible && !backForwardButtonsVisible && !accountSwitcher
    readonly property real themeColorTextContrastFactor: 3.0
    
    property var recentDownloads: []
    property var currentDownloadsDialog: null

    signal chooseAccount()

    // Used for testing. There is a bug that currently prevents non visual Qt objects
    // to be introspectable from AP which makes directly accessing the settings object
    // not possible https://bugs.launchpad.net/autopilot-qt/+bug/1273956
    property alias generatedUrlPatterns: urlPatternSettings.generatedUrlPatterns

    currentWebcontext: currentWebview ? currentWebview.context : null

    actions: [
        Actions.Back {
            enabled: webapp.backForwardButtonsVisible &&
                     containerWebView.currentWebview &&
                     containerWebView.currentWebview.canGoBack
            onTriggered: {
                if (containerWebView.currentWebview.loading) {
                    containerWebView.currentWebview.stop()
                }
                containerWebView.currentWebview.goBack()
            }
        },
        Actions.Forward {
            enabled: webapp.backForwardButtonsVisible &&
                     containerWebView.currentWebview &&
                     containerWebView.currentWebview.canGoForward
            onTriggered: {
                if (containerWebView.currentWebview.loading) {
                    containerWebView.currentWebview.stop()
                }
                containerWebView.currentWebview.goForward()
            }
        },
        Actions.Reload {
            onTriggered: containerWebView.currentWebview.reload()
        }
    ]

    focus: true

    Settings {
        id: urlPatternSettings
        property string generatedUrlPatterns
    }

    function addGeneratedUrlPattern(urlPattern) {
        if (urlPattern.trim().length === 0) {
            return;
        }

        var patterns = []
        if (urlPatternSettings.generatedUrlPatterns
                && urlPatternSettings.generatedUrlPatterns.trim().length !== 0) {
            try {
                patterns = JSON.parse(urlPatternSettings.generatedUrlPatterns)
            } catch(e) {
                console.error("Invalid JSON content found in url patterns file")
            }
            if (! (patterns instanceof Array)) {
                console.error("Invalid JSON content type found in url patterns file (not an array)")
                patterns = []
            }
        }
        if (patterns.indexOf(urlPattern) < 0) {
            patterns.push(urlPattern)

            urlPatternSettings.generatedUrlPatterns = JSON.stringify(patterns)
        }
    }

    function mergeUrlPatternSets(p1, p2) {
        if ( ! (p1 instanceof Array)) {
            return (p2 instanceof Array) ? p2 : []
        }
        if ( ! (p2 instanceof Array)) {
            return (p1 instanceof Array) ? p1 : []
        }
        var p1hash = {}
        var result = []
        for (var i1 in p1) {
            p1hash[p1[i1]] = 1
            result.push(p1[i1])
        }
        for (var i2 in p2) {
            if (! (p2[i2] in p1hash)) {
                result.push(p2[i2])
            }
        }
        return result
    }

    function showWebappSettings()
    {
       webappSettingsViewLoader.active = true;
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
        DownloadsModel.add(downloadIdDataBase, download.url, download.path, download.mimeType, false)

        addNewDownload(download)

        if (webapp.chromeless) {
            showDownloadsDialog(anchorItem)
        } else {
            showDownloadsDialog()
        }
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

        if (!currentDownloadsDialog && chromeLoader.item) {
            if (!webapp.chromeless) {
                chromeLoader.item.downloadNotify = true

                if (!chromeLoader.item.navigationButtonsVisible) {
                    showDownloadsDialog()
                }
            } else {
                showDownloadsDialog(anchorItem)
            }
        }
    }

    function showDownloadsDialog(caller) {
        if (!currentDownloadsDialog && chromeLoader.item) {
            if (!webapp.chromeless) {
                chromeLoader.item.downloadNotify = false
                if (caller === undefined) caller = chromeLoader.item.downloadsButtonPlaceHolder
            } else {
                if (caller === undefined) caller = webapp
            }
            var properties = {"downloadsList": recentDownloads}  
            currentDownloadsDialog = PopupUtils.open(Qt.resolvedUrl("../DownloadsDialog.qml"),
                                                               caller, properties)
        }
    }

    function addNewDownload(download) {
        recentDownloads.unshift(download)
        if (chromeLoader.item && !webapp.chromeless) {
            chromeLoader.item.showDownloadButton = true
        }
        if (currentDownloadsDialog) {
            currentDownloadsDialog.downloadsList = recentDownloads
        }
    }

    Connections {
        target: currentDownloadsDialog
        onShowDownloadsPage: showDownloadsPage()
        onPreview: {
                    PopupUtils.close(currentDownloadsDialog);
                    webapp.currentWebview.url = url;
        }
    }

    /* Only used for anchoring the downloads dialog to the top when chromeless */
    Item {
        id: anchorItem
        anchors {
            top: parent.top
            right: parent.right
        }
        height: units.gu(2)
        width: height
    }

    Item {
        id: webviewContainer
        anchors.fill: parent

        WebappContainerWebview {
            id: containerWebView
            objectName: "webview"

            wide: webapp.wide
            anchors {
                left: parent.left
                right: parent.right
                top: chromeLoader.bottom
            }
            height: parent.height - osk.height - chromeLoader.item.height
            developerExtrasEnabled: webapp.developerExtrasEnabled

            focus: true

            onThemeColorMetaInformationDetected: {
                var color = webappContainerHelper.rgbColorFromCSSColor(theme_color)
                if (!webapp.chromeless && chromeLoader.item && color.length) {
                    chromeLoader.item.backgroundColor = theme_color
                    chromeLoader.item.updateChromeElementsColor(
                            ColorUtils.getMostConstrastedColor(
                                color,
                                Qt.darker(theme_color, themeColorTextContrastFactor),
                                Qt.lighter(theme_color, themeColorTextContrastFactor))
                            )
                }
            }
            onSamlRequestUrlPatternReceived: {
                addGeneratedUrlPattern(urlPattern)
            }
            webappUrlPatterns: mergeUrlPatternSets(urlPatternSettings.generatedUrlPatterns,
                                   webapp.webappUrlPatterns)

            /**
             * Use the --webapp parameter value w/ precedence, but also take into account
             * the fact that a webapp 'name' can come from a webapp-properties.json file w/o
             * being explictly defined here.
             */
            webappName: webapp.webappName

            Loader {
                anchors {
                    fill: containerWebView
                    topMargin: (!webapp.chromeless && chromeLoader.item.state == "shown")
                               ? chromeLoader.item.height
                               : 0
                }
                active: containerWebView.currentWebview &&
                        (webProcessMonitor.crashed || (webProcessMonitor.killed && !containerWebView.currentWebview.loading))
                sourceComponent: SadPage {
                    webview: containerWebView.currentWebview
                    objectName: "mainWebviewSadPage"
                }
                Common.WebProcessMonitor {
                    id: webProcessMonitor
                    webview: containerWebView.currentWebview
                }
                asynchronous: true
            }
        }

        Loader {
            anchors {
                fill: containerWebView
            }
            sourceComponent: Common.ErrorSheet {
                visible: containerWebView.currentWebview && ! containerWebView.currentWebview.loading && containerWebView.currentWebview.lastLoadFailed
                url: containerWebView.currentWebview ? containerWebView.currentWebview.url : ""
                errorString: containerWebView.currentWebview ? containerWebView.currentWebview.lastLoadRequestErrorString : ""
                errorDomain: containerWebView.currentWebview ? containerWebView.currentWebview.lastLoadRequestErrorDomain : -1
                canGoBack: containerWebView.currentWebview && containerWebView.currentWebview.canGoBack
                onBackToSafetyClicked: containerWebView.currentWebview.goBack()
                onRefreshClicked: containerWebView.currentWebview.reload()
            }
            asynchronous: true
        }

        Loader {
            id: chromeLoader

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            sourceComponent: webapp.chromeless ? progressbarComponent : chromeComponent

            Component {
                id: chromeComponent

                Chrome {
                    webview: webapp.currentWebview
                    navigationButtonsVisible: webapp.backForwardButtonsVisible
                    accountSwitcher: webapp.accountSwitcher

                    anchors {
                        left: parent.left
                        right: parent.right
                    }
                    visible: state !== "hidden"
                    height: (state === "hidden") ? 0 : units.gu(6)
                    y: webapp.currentWebview ? containerWebView.currentWebview.locationBarController.offset : 0
                    availableHeight: containerWebView.height

                    onChooseAccount: webapp.chooseAccount()
                    onToggleDownloads: {
                        webapp.showDownloadsDialog()
                    }
                }
            }

            Component {
                id: progressbarComponent

                Common.ThinProgressBar {
                    visible: webapp.currentWebview && webapp.currentWebview.loading
                             && webapp.currentWebview.loadProgress !== 100
                    value: visible ? webapp.currentWebview.loadProgress : 0
                    height: visible ? implicitHeight : 0

                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }
                }
            }
        }

/*
        Binding {
            when: webapp.currentWebview && !webapp.chromeless
            target: webapp.currentWebview ? webapp.currentWebview.locationBarController : null
            property: 'height'
            value: webapp.currentWebview.visible ? chromeLoader.item.height : 0
        }
*/

        Loader {
            id: downloadsViewLoader

            anchors.fill: parent
            active: false
            asynchronous: true
            Component.onCompleted: {
                setSource("../DownloadsPage.qml", {
                              "incognito": false,
                              "focus": true,
                              "subtitle": webapp.dataPath.replace('/home/phablet', '~')
                })
            }

            Connections {
                target: downloadsViewLoader.item
                onDone: downloadsViewLoader.active = false
                onPreview: {
                    downloadsViewLoader.active = false;
                    webapp.currentWebview.url = url;
                }
            }
        }

        Loader {
            id: webappSettingsViewLoader

            anchors.fill: parent
            active: false
            asynchronous: false
            Component.onCompleted: {
                setSource("WebappSettingsPage.qml", {
                              "focus": true,
                              "settingsObject": settings
                          })
            }

            Connections {
                target: webappSettingsViewLoader.item
                onClearCache: {

                    // clear http cache
                    webapp.currentWebview.profile.clearHttpCache();

                    var cacheLocationUrl = Qt.resolvedUrl(cacheLocation);
                    var dataLocationUrl = Qt.resolvedUrl(webapp.dataPath);

                    // clear favicons
                    FileOperations.removeDirRecursively(cacheLocationUrl + "/favicons");

                    // remove captures
                    FileOperations.removeDirRecursively(cacheLocationUrl + "/captures");

                    // application cache
                    FileOperations.removeDirRecursively(dataLocationUrl + "/Application Cache");

                    // File System
                    FileOperations.removeDirRecursively(dataLocationUrl + "/File System");

                    // Local Storage
                    FileOperations.removeDirRecursively(dataLocationUrl + "/Local Storage");

                    // Service WorkerScript
                    FileOperations.removeDirRecursively(dataLocationUrl + "/Service Worker")

                    // visited Links
                    FileOperations.remove(dataLocationUrl + "/Visited Links");
                }
                onClearAllCookies: {
                    BrowserUtils.deleteAllCookiesOfProfile(webapp.currentWebview.profile);
                }
                onDone: webappSettingsViewLoader.active = false
                onShowDownloadsPage: webapp.showDownloadsPage()
            }
        }

       Connections {
            target: webapp.currentWebview
            enabled: !webapp.chromeless

            onIsFullScreenChanged: {
                if (webapp.currentWebview.isFullScreen) {
                    chromeLoader.item.state = "hidden";
                } else {
                    chromeLoader.item.state = "shown";
                }
            }
       }

       Connections {

           target: webapp.currentWebview ? webapp.currentWebview.context : null

           onDownloadRequested: {

               console.log("a download was requested with path %1".arg(download.path))

               download.accept();
               webapp.startDownload(download);
           }

           onDownloadFinished: {

               console.log("a download was finished with path %1.".arg(download.path))
               webapp.setDownloadComplete(download)
           }
       }

       Connections {
           target: settings
           onZoomFactorChanged: DomainSettingsModel.defaultZoomFactor = settings.zoomFactor
           onDomainWhiteListModeChanged: DomainPermissionsModel.whiteListMode = settings.domainWhiteListMode
       }

        Common.ChromeController {
            webview: webapp.currentWebview
            forceHide: webapp.chromeless
        //    defaultMode: webapp.hasTouchScreen
        //                     ? Oxide.LocationBarController.ModeAuto
        //                     : Oxide.LocationBarController.ModeShown
        }
    }

    // F5 or Ctrl+R: Reload current Tab
    Shortcut {
        sequence: "Ctrl+r"
        enabled: currentWebview && currentWebview.visible
        onActivated: currentWebview.reload()
    }
    Shortcut {
        sequence: "F5"
        enabled: currentWebview && currentWebview.visible
        onActivated: currentWebview.reload()
    }

    // Alt+← or Backspace: Goes to the previous page
    Shortcut {
        sequence: StandardKey.Back
        enabled: currentWebview && currentWebview.canGoBack
        onActivated: currentWebview.goBack()
    }

    // Alt+→ or Shift+Backspace: Goes to the next page
    Shortcut {
        sequence: StandardKey.Forward
        enabled: currentWebview && currentWebview.canGoForward
        onActivated: currentWebview.goForward()
    }
}
