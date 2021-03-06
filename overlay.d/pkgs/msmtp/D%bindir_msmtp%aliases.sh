#!/bin/sh
# --- SDE-COPYRIGHT-NOTE-BEGIN ---
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
#
# Filename: target/mnemosyne/overlay.d/pkgs/msmtp/D%bindir_msmtp%aliases.sh
# Copyright (C) 2010 The OpenSDE Project
#
# More information can be found in the files COPYING and README.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. A copy of the
# GNU General Public License can be found in the file COPYING.
# --- SDE-COPYRIGHT-NOTE-END ---

DOMAIN=example.org
TMPFILE="/tmp/msmtp.$$"

MSMTP=D_bindir/msmtp

log() {
	echo "$*" >> /var/log/msmtp.log
}

log "[$$]  $0 $*"

cat > $TMPFILE # email content
ARGS= mangled= read_recipients=

while [ $# -gt 0 ]; do
	case "$1" in
	-f|-O|-ox|-X|-C|-a|-N|-R|-L)
		ARGS="$ARGS $1 $2"; shift ;;
	-t)	ARGS="$ARGS $1" read_recipients=yes ;;
	--)	ARGS="$ARGS --"; break ;;
	-*)	ARGS="$ARGS $1" ;;
	*)	break;
	esac
	shift
done

alias_of() {
	local x="$1" alias=
	alias=$(awk -- "/^$x:/ { print \$2;}" "/etc/aliases" 2> /dev/null)
	echo "${alias:-$x@$DOMAIN}"
}

for x; do
	case "$x" in
	*@*) ARGS="$ARGS $x" ;;
	*)
		ARGS="$ARGS $(alias_of $x)"
		mangled=true
		;;
	esac
done

if [ -n "$read_recipients" ]; then
	for x in $(sed -n -e 's,^To: .*<\([^@]\+\)>$,\1,p' "$TMPFILE"); do
		y="$(alias_of $x)"
		log "[$$]  To: <$x> -> <$y>"
		sed -i "s,^To: \(.*\)<$x>$,To: \1<$y>," "$TMPFILE"
	done
fi

eval "set -- $ARGS"
[ -z "$mangled" ] || log "[$$]+ $0 $@"

"$MSMTP" "$@" < "$TMPFILE"
errno=$?
rm -f "$TMPFILE"
exit $errno
