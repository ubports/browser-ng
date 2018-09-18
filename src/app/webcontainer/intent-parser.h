/*
 * Copyright 2014-2015 Canonical Ltd.
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

#ifndef _INTENT_PARSER_H_
#define _INTENT_PARSER_H_

#include <QString>


class QUrl;

struct IntentUriDescription
{
    QString uriPath;

    // optional
    QString host;

    QString package;
    QString action;
    QString category;
    QString component;
    QString scheme;
};

/**
 * @brief Parse a URI that is supposed to be an intent as defined here
 *
 * https://developer.chrome.com/multidevice/android/intents
 *
 * @param intentUri
 * @return
 */
IntentUriDescription parseIntentUri(const QUrl& intentUri);

#endif // _INTENT_PARSER_H_
