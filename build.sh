# --- T2-COPYRIGHT-NOTE-BEGIN ---
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# 
# T2 SDE: target/mnemosyne2/build.sh
# Copyright (C) 2004 - 2005 The T2 SDE Project
# 
# More information can be found in the files COPYING and README.
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License. A copy of the
# GNU General Public License can be found in the file COPYING.
# --- T2-COPYRIGHT-NOTE-END ---

pkgloop_action() {
	local rc=
        $cmd_buildpkg ; rc=$?

	if [ -f config/$config/.pause ]; then
		echo_status "mnemosyne: pausing building..."
		rm -f config/$config/.pause
		exit 0
	fi
	return $rc
}

. target/generic/build.sh
