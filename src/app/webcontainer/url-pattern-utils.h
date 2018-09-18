/*
 * Copyright 2014 Canonical Ltd.
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

#ifndef URLPATTERNUTILS_H
#define URLPATTERNUTILS_H

#include <QtCore/QString>
#include <QtCore/QStringList>


class QUrl;

namespace UrlPatternUtils {

/**
 * @brief transformWebappSearchPatternToSafePattern
 * @param doTransformUrlPath
 * @return
 */
QString transformWebappSearchPatternToSafePattern(const QString&
                                                  , bool doTransformUrlPath = true);

/**
 * @brief isLocalHtml5ApplicationHomeUrl
 * @return
 */
bool isLocalHtml5ApplicationHomeUrl(const QUrl&);

/**
 * @brief filterAndTransformUrlPatterns
 * @param includePatterns
 * @return
 */
QStringList filterAndTransformUrlPatterns(const QStringList & includePatterns);

}


#endif // URLPATTERNUTILS_H
