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

pragma Singleton

import QtQuick 2.4
import QtWebEngine 1.5
import webbrowserapp.private 0.1
import webbrowsercommon.private 0.1
import Morph.Web 0.1

Item {
    property string capturesDir:  cacheLocation + "/captures"
    signal previewSaved(url pageUrl, url previewUrl)

    LimitProxyModel {
        id: topSites
        limit: 10
        sourceModel: TopSitesModel {
            model: HistoryModel
        }
        function contains(url) {
            for (var i = 0; i < topSites.count; i++) {
                if (topSites.get(i).url == url) return true
            }
            return false
        }
        function containsHash(hash) {
            for (var i = 0; i < topSites.count; i++) {
                if (Qt.md5(topSites.get(i).url) === hash) return true
            }
            return false
        }
    }

    function previewPathFromUrl(url) {
        return "%1/%2.png".arg(capturesDir).arg(Qt.md5(url))
    }

    function saveToDisk(data, url) {
        if (!FileOperations.exists(Qt.resolvedUrl(capturesDir))) {
            FileOperations.mkpath(Qt.resolvedUrl(capturesDir))
        }

        var filepath = previewPathFromUrl(url)
        var previewUrl = ""
        if (data.saveToFile(filepath)) previewUrl = Qt.resolvedUrl(filepath)
        else console.warn("Failed to save preview to disk for %1 (path is %2)".arg(url).arg(filepath))

        previewSaved(url, previewUrl)
    }


    function checkDelete(url) {
        if (!topSites.contains(url)) {
            FileOperations.remove(Qt.resolvedUrl(previewPathFromUrl(url)))
        }
    }

    // Remove all previews stored on disk that are not part of the top sites
    // and that are not for URLs in the doNotCleanUrls list
    function cleanUnusedPreviews(doNotCleanUrls) {
        var dir = Qt.resolvedUrl(capturesDir)
        var previews = FileOperations.filesInDirectory(dir, ["*.png", "*.jpg"])
        var doNotCleanHashes = doNotCleanUrls.map(function(url) { return Qt.md5(url) })
        for (var i in previews) {
            var preview = previews[i]
            var hash = preview.split('.')[0]
            if (!topSites.containsHash(hash) && (doNotCleanHashes.indexOf(hash) === -1)) {
                var file = Qt.resolvedUrl("%1/%2".arg(capturesDir).arg(preview))
                FileOperations.remove(file)
            }
        }
    }
}
