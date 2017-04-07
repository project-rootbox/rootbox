#!/bin/sh

cd "`dirname $0`"
prefix=${1:-/usr/local}

set -ex

install -m 755 bin/rootbox "$prefix/bin/rootbox"

for file in lib/rootbox/*.sh lib/rootbox/LICENSE* lib/rootbox/cmdarg/*; do
  install -Dm 644 $file "$prefix/$file"
done
