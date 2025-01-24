#!/usr/bin/env sh

if [ -z $1 ]; then
	echo USAGE: $0 INPUT
	exit 1
fi

PATH="$PATH:$(dirname $0)/../zig-out/bin"

lmc-as <$1 >/tmp/lmc-out
lmci /tmp/lmc-out
rm /tmp/lmc-out
