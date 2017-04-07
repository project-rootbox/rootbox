#!/bin/sh

cd "`dirname $0`"
prefix=${1:-/usr/local}

set -ex

rm -rf "$prefix/lib/rootbox/cmdarg"

install -m 755 bin/rootbox "$prefix/bin/rootbox"

for file in lib/rootbox/*.sh lib/rootbox/LICENSE* lib/rootbox/argparser/*; do
  install -Dm 644 $file "$prefix/$file"
done
