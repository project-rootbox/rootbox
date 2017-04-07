#!/bin/sh

cd "`dirname $0`"
prefix=${1:-/usr/local}

set -ex

mkdir -p "$prefix/lib/rootbox/cmdarg"

ln -sf "$PWD/bin/rootbox" "$prefix/bin/rootbox"

for file in lib/rootbox/*.sh lib/rootbox/LICENSE* lib/rootbox/cmdarg/*; do
  ln -sf "$PWD/$file" "$prefix/$file"
done
