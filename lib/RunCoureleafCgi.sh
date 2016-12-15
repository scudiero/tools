## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.5" # -- dscudiero -- 12/02/2016 @ 16:21:39.99
#===================================================================================================
# Run a courseleaf.cgi command, check outpout
# Courseleaf.cgi $LINENO <siteDir> <command string>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function RunCoureleafCgi {
	local siteDir="$1"; shift
	local cgiCmd="$*"

	cwd=$(pwd)
	cd $siteDir
	courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1).cgi
	courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
	if [[ $courseLeafPgm == '.cgi' || $courseLeafDir == '' ]]; then Msg2 $T "Could not find courseleaf executable"; fi
	dump -3  siteDir courseLeafPgm courseLeafDir cgiCmd
	[[ ! -x $courseLeafDir/$courseLeafPgm ]] && Msg2 $TT1 "Could not find $courseLeafPgm in '$courseLeafDir' trying:\n^'$cgiCmd'\n^($calledLineNo)"

	## Run command
	cd $courseLeafDir
	local cgiOut=/tmp/$userName.$myName.$BASHPID.cgiOut
	$DOIT ./$courseLeafPgm $cgiCmd 2>&1 > $cgiOut; rc=$?
	grepStr="$(ProtectedCall "grep 'ATJ error:' $cgiOut")"
	[[ $grepStr != '' ]] && Msg2 $TT1 "ATJ errors were reported by the step.\n^Cgi cmd: '$cgiCmd'\n^Please see below:\n^$grepStr\n\tAdditional information may be found in:\n^$cgiOut"
	rm -f $cgiOut
	cd $cwd
	return 0
} #RunCoureleafCgi
export -f RunCoureleafCgi

#===================================================================================================
# Check-in Log
#===================================================================================================

