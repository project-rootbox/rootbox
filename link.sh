#!/bin/sh

cd "`dirname $0`"
prefix=${1:-/usr/local}

set -ex

rm -rf "$prefix/lib/rootbox/cmdarg"

ln -sf "$PWD/bin/rootbox" "$prefix/bin/rootbox"
ln -sf "$PWD/lib/rootbox" "$prefix/lib/rootbox"
