#!/bin/sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e

URL="https://github.com/project-rootbox/rootbox/archive/master.tar.gz"

set -x

cd ${TMP:-/tmp}
curl -fL "$URL" -o rootbox.tar.gz
tar xvf rootbox.tar.gz

cd rootbox-master
sh install.sh "$1"
