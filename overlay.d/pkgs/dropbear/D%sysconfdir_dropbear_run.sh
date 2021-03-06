#!/bin/sh
# --- SDE-COPYRIGHT-NOTE-BEGIN ---
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
#
# Filename: target/mnemosyne/overlay.d/pkgs/dropbear/D%sysconfdir_dropbear_run.sh
# Copyright (C) 2010 The OpenSDE Project
#
# More information can be found in the files COPYING and README.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. A copy of the
# GNU General Public License can be found in the file COPYING.
# --- SDE-COPYRIGHT-NOTE-END ---

exec 2>&1

DROPBEAR_LISTEN=
DROPBEAR_PASSWD=
DROPBEAR_EXTRA_OPT=

if [ -s /etc/conf/dropbear ]; then
	. /etc/conf/dropbear
fi

dbopt="-F -E"
for x in $DROPBEAR_LISTEN; do
	case "$x" in
	*:*)	dbopt="$dbopt -p $x" ;;
	*)	dbopt="$dbopt -p $x:22" ;;
	esac
done
[ "$DROPBEAR_PASSWD" != "no" ] || dbopt="$dbopt -s"

exec D_sbindir/dropbear $dbopt $DROPBEAR_EXTRA_OPT
