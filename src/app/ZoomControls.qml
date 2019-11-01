import QtQuick 2.4
import Ubuntu.Components 1.3                  // For UbuntuShape.
import Ubuntu.Components.Popups 1.3 as Popups // For saveDialog.
import QtWebEngine 1.7
import webbrowsercommon.private 0.1           // For DomainSettingsModel singleton.
import "UrlUtils.js" as UrlUtils

// ZoomControls object to provide zoom menu, control and autofit logic for WebViewImpl.
// Scope requirements:
//     webview:             An WebViewImpl object for zoomFactor manipulation and signal bindings.
//     browser (or webapp): An Browser (or WebApp) object for settings operations.
UbuntuShape {
    z:3
    id: menu
    objectName: "zoomActions"
    visible: false
    aspect: UbuntuShape.DropShadow
    backgroundColor: theme.palette.normal.background
    width: zoomActionsRow.width + padding * 2
    height: zoomActionsRow.height + currentZoomText.height + padding * 2
    x: (webview.width - width) / 2
    y: (webview.height - height) / 2

    readonly property int padding: units.gu(1)
    readonly property alias controller: controller

    MouseArea {
        // without that MouseArea the user can click "through" inactive parts of the page menu (e.g the text of current zoom value)
        anchors.fill: menu
        onClicked: console.log("inactive part of zoom menu clicked.")
    }

    ActionList {
        id: zoomActions
        Action {
            name: "fitToWidth"
            text: i18n.tr("Fit (%1%)".arg(isNaN(controller.fitToWidthFactor) ? "-" : controller.fitToWidthFactor * 100))
            iconName: "zoom-fit-best"
            enabled: !isNaN(controller.fitToWidthFactor) && (Math.abs(controller.currentZoomFactor - controller.fitToWidthFactor) >= 0.01 || controller.viewSpecificZoom === false)
            onTriggered: controller.fitToWidth()
        }
        Action {
            name: "zoomOut"
            text: i18n.tr("Zoom Out")
            iconName: "zoom-out"
            enabled: Math.abs(controller.currentZoomFactor - controller.minZoomFactor) >= 0.01
            onTriggered: controller.zoomOut()
        }
        Action {
            name: "zoomOriginal"
            text: i18n.tr("Reset") + " (%1%)".arg(controller.defaultZoomFactor * 100)
            iconName: "reset"
            enabled: controller.viewSpecificZoom || Math.abs(controller.currentZoomFactor - controller.defaultZoomFactor) >= 0.01
            onTriggered: controller.resetSaveFit()
        }
        Action {
            name: "zoomIn"
            text: i18n.tr("Zoom In")
            iconName: "zoom-in"
            enabled: Math.abs(controller.currentZoomFactor - controller.maxZoomFactor) >= 0.01
            onTriggered: controller.zoomIn()
        }
        Action {
            name: "zoomSave"
            text: i18n.tr("Save")
            iconName: "save"
            enabled: saveDomainButton.enabled || saveDefaultButton.enabled
            onTriggered: controller.save()
        }
        Action {
            name: "close"
            text: i18n.dtr('ubuntu-ui-toolkit', "Close")
            iconName: "close"
            enabled: true
            onTriggered: menu.visible = false
        }
    }

    Row {
        id: zoomActionsRow
        x: parent.padding
        y: parent.padding
        height: units.gu(6)

        Repeater {
            model: zoomActions.children
            AbstractButton {
                objectName: "pageAction_" + action.name
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Math.max(units.gu(4), implicitWidth) + units.gu(1)
                action: modelData
                styleName: "ToolbarButtonStyle"
                activeFocusOnPress: false
            }
        }
    }

    Text {
        id: currentZoomText
        anchors.top: zoomActionsRow.bottom
        anchors.right: zoomActionsRow.right
        text: i18n.tr("Current Zoom") + ": " + Math.round(controller.currentZoomFactor * 100) + "%"
        + " (%1)".arg(controller.viewSpecificZoom ? i18n.tr("domain") : (controller.currentZoomFactor === controller.defaultZoomFactor ? i18n.tr("default") : i18n.tr("auto-fit")))
        color: theme.palette.normal.backgroundText
        width: zoomActionsRow.width
        horizontalAlignment: Text.AlignHCenter
    }

    onVisibleChanged: {
        console.log("menu.visible triggered: %1 (%2)".arg(visible).arg(webview.url));
        if (visible && webview.url != "" && internal.currentDomainScrollWidth === 0) {
            controller.retrieveScrollWidth();
        }
    }

    QtObject {
        id: internal

        property bool viewSpecificZoom: false
        property real currentZoomFactor: controller.defaultZoomFactor

        property int currentDomainScrollWidth: 0
        property real currentDomainZoomFactor: NaN

        property bool refreshZoomOnWebViewVisible: false
        property bool anyPageLoaded: false

        property Timer autoFitToWidthTimer: Timer {
            interval: 1000
            running: false
            repeat: false
            onTriggered: {
                console.log("autoFitToWidthTimer triggered");
                controller.autoFitToWidth();
            }
        }

        property Timer widthChangedTimer: Timer {
            interval: 300
            running: false
            repeat: false
            onTriggered: {
                console.log("webview.widthChangedTimer triggered");
                if (webview.loading === true) {
                    console.log("  webview is currently loading, skipping fit to width");
                    return;
                }

                if (controller.autoFitToWidthEnabled && controller.viewSpecificZoom === false) {
                    controller.autoFitToWidthFromDefaultZoomFactor();
                }
                else if (menu.visible) {
                    controller.retrieveScrollWidth();
                }
            }
        }

        property Connections webviewConnections: Connections {
            target: webview
            onWidthChanged: {
                console.log("ZoomControls: webview.onWidthChanged called: %1".arg(width));
                if (internal.anyPageLoaded === false) {
                    console.log("  no page was loaded")
                    return;
                }

                if (webview.visible === false) {
                    console.log("  webview not visible, setting flag to refresh after visible and skipping fit to width");
                    internal.refreshZoomOnWebViewVisible = true;
                    return;
                }

                internal.currentDomainScrollWidth = 0;
                internal.widthChangedTimer.restart();
            }

            onLoadingChanged: {
                console.log("ZoomControls webview.onLoadingChanged: %1".arg(webview.url));
                console.log("  webview.loading: %1".arg(webview.loading));

                // not about current url (e.g. finished loading of page we have already navigated away from)
                if (loadRequest.url !== webview.url) {
                    return;
                }

                if (loadRequest.status === WebEngineLoadRequest.LoadSucceededStatus) {
                    console.log("  webview.onLoadingChanged: LoadSucceeded");
                    internal.anyPageLoaded = true;

                    if (webview.visible === false) {
                        console.log("  webview not visible, setting flag to refresh after visible and skipping fit to width");
                        internal.refreshZoomOnWebViewVisible = true;
                        return;
                    }

                    // This is a workaround, because sometimes a page is not zoomed after loading (happens after manual url change),
                    // although the webview.zoomFactor (and currentZoomFactor) is correctly set.
                    webview.zoomFactor = controller.currentZoomFactor;
                    // End of workaround.

                    if (internal.currentDomainScrollWidth === 0) {
                        if (controller.autoFitToWidthEnabled && controller.viewSpecificZoom === false) {
                            controller.autoFitToWidthFromDefaultZoomFactor();
                        }
                        else if (menu.visible) {
                            controller.retrieveScrollWidth();
                        }
                    }
                }
            }
        }

        property Connections domainSettingsModelConnections: Connections {
            target: DomainSettingsModel

            // If database changed, reload zoomFactor according to new db.
            // This is a workaround. Because if browser runs with previously opened pages (session), the DomainSettingsModel is not initialized yet
            // when onCurrentDomainChanged is trigerred first time. I couldn't figure out, how to initialize DomainSettingsModel prior signaling.
            // So wait, until db is initialized, then trigger onCurrentDomainChanged again.
            onDatabasePathChanged: {
                console.log("ZoomControls DomainSettingsModel.onDatabasePathChanged triggered");
                if (webview.visible === false) {
                    console.log("  webview not visible, setting flag to refresh after visible and skipping fit to width");
                    internal.refreshZoomOnWebViewVisible = true;
                    return;
                }

                controller.zoomPageForCurrentDomain();
            }
            onDomainZoomFactorChanged: {
                console.log("ZoomControls DomainSettingsModel.onDomainZoomFactorChanged triggered: %1".arg(domain));
                if (domain != controller.currentDomain) {
                    // Not my current domain changed, nothing to do here.
                    console.log("  not my domain (%1) changed".arg(controller.currentDomain));
                    return;
                }

                // Zoom factor for current domain was changed, check if we are up to date with the change.
                internal.currentDomainZoomFactor = DomainSettingsModel.getZoomFactor(controller.currentDomain);
                if (
                    (isNaN(internal.currentDomainZoomFactor) && internal.viewSpecificZoom === false)
                    ||
                    (!isNaN(internal.currentDomainZoomFactor) && internal.viewSpecificZoom === true && internal.currentZoomFactor === internal.currentDomainZoomFactor)
                ) {
                    // Our zoom settings are up to date to domainZoomFactor, nothing to do here.
                    console.log("  up to date");
                    return;
                }

                // We need to adjust zoom settings now, or in the future.
                if (webview.visible === false) {
                    // Webview is not visible, flag to update after visible and return.
                    console.log("  webview not visible, setting flag to refresh after visible and skipping zoom setting update");
                    internal.refreshZoomOnWebViewVisible = true;
                    return;
                }

                // Adjust zoom settings according to domainZoomFactor and fit if neccessary.
                controller.zoomPageForCurrentDomain();

                if (webview.loading === true) {
                    // Webview is currently loading a page, so no need to refresh fit, cause it will be refreshed after loading.
                    console.log("  webview is currently loading, skipping fit to width");
                    return;
                }

                if (controller.autoFitToWidthEnabled && controller.viewSpecificZoom === false) {
                    controller.autoFitToWidthFromDefaultZoomFactor();
                }
                else if (menu.visible) {
                    controller.retrieveScrollWidth();
                }
            }
        }

        property Connections webview_onVisibleChanged: Connections {
            target: webview
            onVisibleChanged: {
                console.log("ZoomControls webview.onVisibleChanged triggered: %1 (%2)".arg(webview.visible).arg(webview.url));
                if (internal.anyPageLoaded === false) {
                    console.log("  no page was loaded")
                    return;
                }
                if (webview.visible === true && internal.refreshZoomOnWebViewVisible === true) {
                    console.log("  refreshing zoom and fit after visible");
                    internal.refreshZoomOnWebViewVisible = false;

                    // Reload zoom levels for current domain.
                    controller.zoomPageForCurrentDomain();

                    if (webview.loading === true) {
                        // If webview is currently loading a page, no need to refresh fit, cause it will be refreshed after loading (if neccessary).
                        console.log("  webview is currently loading, skipping fit to width");
                        return;
                    }

                    if (controller.autoFitToWidthEnabled && controller.viewSpecificZoom === false) {
                        controller.autoFitToWidthFromDefaultZoomFactor();
                    }
                    else if (menu.visible) {
                        controller.retrieveScrollWidth();
                    }
                }
            }
        }
    }

    QtObject {
        id: controller

        // Contains domain, or scheme if webview.url has no domain.
        readonly property string currentDomain: UrlUtils.hostIs(webview.url, "") ? "scheme:" + UrlUtils.extractScheme(webview.url) : UrlUtils.extractHost(webview.url)

        readonly property real defaultZoomFactor: browser.settings ? browser.settings.zoomFactor : webapp.settings.zoomFactor
        readonly property real minZoomFactor: 0.25
        readonly property real maxZoomFactor: 5.0
        readonly property alias currentZoomFactor: internal.currentZoomFactor
        readonly property alias viewSpecificZoom: internal.viewSpecificZoom

        readonly property bool autoFitToWidthEnabled: browser.settings ? browser.settings.autoFitToWidthEnabled : webapp.settings.autoFitToWidthEnabled
        readonly property real fitToWidthFactor: internal.currentDomainScrollWidth > 0 ? Math.max(minZoomFactor, Math.min(maxZoomFactor, Math.floor((webview.width / internal.currentDomainScrollWidth) * 100) / 100)) : NaN

        function fitToWidth() {
            console.log("ZoomControls.fitToWidth: %1".arg(fitToWidthFactor));
            if (isNaN(fitToWidthFactor)) {
                console.log("  not applying");
                return;
            }

            internal.viewSpecificZoom = true;
            internal.currentZoomFactor = fitToWidthFactor;
            if (! webview.incognito) {
                saveZoomFactorForCurrentDomain();
            }
        }

        function zoomIn() {
            internal.viewSpecificZoom = true;
            internal.currentZoomFactor = Math.min(maxZoomFactor, currentZoomFactor + ((Math.round(currentZoomFactor * 100) % 10 === 0) ? 0.1 : 0.1 - (currentZoomFactor % 0.1)));
            if (! webview.incognito) {
                saveZoomFactorForCurrentDomain();
            }
        }

        function resetSaveFit() {
            internal.viewSpecificZoom = false;
            internal.currentZoomFactor = defaultZoomFactor;
            if (! webview.incognito) {
                saveZoomFactorForCurrentDomain();
            }

            if (webview.loading === true) {
                // If webview is currently loading a page, no need to refresh fit, cause it will be refreshed after loading (if neccessary).
                console.log("  webview is currently loading, skipping fit to width");
                return;
            }

            internal.currentDomainScrollWidth = 0;
            if (autoFitToWidthEnabled && viewSpecificZoom === false) {
                autoFitToWidthFromDefaultZoomFactor();
            }
            else {
                retrieveScrollWidth();
            }
        }

        function zoomOut() {
            internal.viewSpecificZoom = true
            internal.currentZoomFactor = Math.max(minZoomFactor, currentZoomFactor - ((Math.round(currentZoomFactor * 100) % 10 === 0) ? 0.1 : currentZoomFactor % 0.1));
            if (! webview.incognito) {
                saveZoomFactorForCurrentDomain();
            }
        }

        function save() {
            saveDialog.show();
        }

        function saveZoomFactorForCurrentDomain() {
            if (viewSpecificZoom) {
                DomainSettingsModel.setZoomFactor(currentDomain, currentZoomFactor);
            }
            else {
                DomainSettingsModel.setZoomFactor(currentDomain, NaN);
            }
        }

        function autoFitToWidthFromDefaultZoomFactor() {
            console.log("ZoomControls.autoFitToWidthFromDefaultZoomFactor called");
            if (internal.currentDomainScrollWidth !== 0 || webview.loading === true || autoFitToWidthEnabled === false || viewSpecificZoom === true) {
                console.log("Warning: calling autoFitToWidthFromDefaultZoomFactor when not intended?");
            }
            // Zoom to defaultZoomFactor before determining scrollWidth, to allways get consistent numbers.
            webview.zoomFactor = defaultZoomFactor;
            internal.autoFitToWidthTimer.restart();
        }

        function autoFitToWidth() {
            // This function might be called when webview.zoomFactor != currentZoomFactor.
            console.log("ZoomControls.autoFitToWidth called");

            // Determine scrollWidth and use it to fit to width.
            webview.runJavaScript("document && document.body ? document.body.scrollWidth : null", function(width) {
                console.log("  body.scrollWidth: %1 (%2 * %3)".arg(width).arg(webview.width).arg(webview.zoomFactor));
                if (width > 0) {
                    var newZoomFactor = Math.max(minZoomFactor, Math.min(maxZoomFactor, Math.floor((webview.width / width) * 100) / 100));
                    if (Math.abs(currentZoomFactor - newZoomFactor) >= 0.1) {
                        console.log("  newZoomFactor: %1".arg(newZoomFactor));
                        internal.currentZoomFactor = newZoomFactor;
                    }
                    else {
                        console.log("  not autofitting, close to currentZoomFactor");
                        webview.zoomFactor = currentZoomFactor;
                    }
                    internal.currentDomainScrollWidth = width;
                }
                else {
                    console.log("  not autofitting, no scrollWidth");
                    webview.zoomFactor = currentZoomFactor;
                }
            });
        }

        function retrieveScrollWidth() {
            console.log("ZoomControls.retrieveScrollWidth called");
            if (internal.currentDomainScrollWidth !== 0 || webview.loading === true || (autoFitToWidthEnabled === true && viewSpecificZoom === false) || menu.visible === false) {
                console.log("Warning: calling retrieveScrollWidth when not intended?\n%1 %2 %3 %4 %5".arg(internal.currentDomainScrollWidth).arg(webview.loading).arg(autoFitToWidthEnabled).arg(viewSpecificZoom).arg(menu.visible));
            }
            webview.runJavaScript("document && document.body ? document.body.scrollWidth : null", function(width) {
                console.log("  body.scrollWidth: %1 (%2 * %3)".arg(width).arg(webview.width).arg(currentZoomFactor));
                internal.currentDomainScrollWidth = width > 0 ? width : 0;
            });
        }

        function zoomPageForCurrentDomain() {
            console.log("ZoomControls.zoomPageForCurrentDomain called: %1".arg(controller.currentDomain));
            if (DomainSettingsModel.databasePath === "") {
                console.log("  no database for domain settings");
                return;
            }

            internal.currentDomainScrollWidth = 0;
            internal.currentDomainZoomFactor = DomainSettingsModel.getZoomFactor(controller.currentDomain);
            if (isNaN(internal.currentDomainZoomFactor) ) {
                internal.viewSpecificZoom = false;
                internal.currentZoomFactor = defaultZoomFactor;
            }
            else {
                internal.viewSpecificZoom = true;
                internal.currentZoomFactor = internal.currentDomainZoomFactor;
            }
            console.log("  viewSpecificZoom: %1".arg(viewSpecificZoom));
            console.log("  currentZoomFactor: %1".arg(currentZoomFactor));
        }

        onCurrentDomainChanged: {
            console.log("ZoomControls.onCurrentDomainChanged triggered");
            if (webview.visible === false) {
                console.log("  webview not visible, setting flag to refresh after visible and skipping page zoom");
                internal.refreshZoomOnWebViewVisible = true;
                return;
            }

            controller.zoomPageForCurrentDomain();
        }

        onDefaultZoomFactorChanged: {
            console.log("ZoomControls.onDefaultZoomFactorChanged: %1 (%2)".arg(defaultZoomFactor).arg(webview.url));
            if (internal.anyPageLoaded === false) {
                console.log("  no page was loaded")
                return;
            }

            if (webview.visible === false) {
                console.log("  webview not visible, setting flag to refresh after visible and skipping page zoom");
                internal.refreshZoomOnWebViewVisible = true;
                return;
            }

            if (viewSpecificZoom === false) {
                // Page is currently in default zoom mode, change current zoom and handle fit to width.
                internal.currentZoomFactor = defaultZoomFactor;

                if (webview.loading === true) {
                    // If webview is currently loading a page, no need to refresh fit, cause it will be refreshed after loading (if neccessary).
                    console.log("  webview is currently loading, skipping fit to width");
                    return;
                }
                internal.currentDomainScrollWidth = 0;
                if (autoFitToWidthEnabled) {
                    autoFitToWidthFromDefaultZoomFactor();
                }
                else if (menu.visible) {
                    retrieveScrollWidth();
                }
            }
        }

        onCurrentZoomFactorChanged: {
            console.log("ZoomControls.onCurrentZoomFactorChanged: %1".arg(currentZoomFactor));
            webview.zoomFactor = currentZoomFactor;
        }

        onAutoFitToWidthEnabledChanged: {
            console.log("ZoomControls.onAutoFitToWidthEnabledChanged: %1".arg(autoFitToWidthEnabled));
            // Handling is the same as onDefaultZoomFactorChanged, so just trigger it.
            defaultZoomFactorChanged();
        }
    }

    Popups.Dialog {
        id: saveDialog
        parent: webapp
        objectName: "saveZoomFactorDialog"
        title: i18n.tr("Save Zoom")
        readonly property string saveDomainText: saveDomainButton.enabled ? i18n.tr("domain zoom (which is currently %1 and can be removed with reset button or from domain specific settings in privacy settings)".arg(isNaN(internal.currentDomainZoomFactor) ? i18n.tr("none") : Math.round(internal.currentDomainZoomFactor * 100) + "%")) : ""
        readonly property string saveDefaultText: saveDefaultButton.enabled ? i18n.tr("default zoom (whis is crrently %1% and can be changed from setting menu)".arg(Math.round(controller.defaultZoomFactor * 100))) : ""
        text: i18n.tr("Current zoom (%1%) can be saved as ".arg(Math.round(controller.currentZoomFactor * 100)))
        + saveDomainText
        + (saveDomainButton.enabled && saveDefaultButton.enabled ? i18n.tr(" or ") : "")
        + saveDefaultText
        // i18n.tr("Set current zoom as default zoom for %1 ? (You can change it in the settings menu)".arg(isWebApp ? i18n.tr("the current web app") : "morph-browser"))

        Button {
            id: saveDomainButton
            text: i18n.tr("Save for domain")
            color: theme.palette.normal.positive
            objectName: "saveDomainButton"
            enabled: isNaN(internal.currentDomainZoomFactor) || Math.abs(controller.currentZoomFactor - internal.currentDomainZoomFactor) >= 0.01
            onClicked: {
                internal.viewSpecificZoom = true;
                controller.saveZoomFactorForCurrentDomain();
                saveDialog.hide();
            }
        }

        Button {
            id: saveDefaultButton
            text: i18n.tr("Save as default")
            color: theme.palette.normal.positive
            objectName: "saveDefaultButton"
            enabled: Math.abs(controller.currentZoomFactor - controller.defaultZoomFactor) >= 0.01
            onClicked: {
                if (browser.settings) {
                    browser.settings.zoomFactor = controller.currentZoomFactor;
                }
                else {
                    webapp.settings.zoomFactor = controller.currentZoomFactor;
                }
                saveDialog.hide();
            }
        }

        Button {
            objectName: "cancelButton"
            text: i18n.tr("Cancel")
            onClicked: {
                saveDialog.hide();
            }
        }
    }
}
