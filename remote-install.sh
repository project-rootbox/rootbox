#!/bin/sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e

URL="https://github.com/project-rootbox/rootbox/archive/master.tar.gz"

echo "Running system checks..."

[ `id -u` != 0 ] || echo "This should not be run as root!" >&2
which "$1" >/dev/null 2>&1 || echo "curl is required to download Rootbox." >&2

set -x

cd ${TMP:-/tmp}
curl -fL "$URL" -o rootbox.tar.gz
tar xvf rootbox.tar.gz

cd rootbox-master
sudo sh install.sh "$1"
