## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.21" # -- dscudiero -- Thu 05/25/2017 @ 13:25:32.27
#===================================================================================================
# Run a courseleaf.cgi command, check outpout
# Courseleaf.cgi $LINENO <siteDir> <command string>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function RunCourseLeafCgi {
	local siteDir="$1"; shift
	local cgiCmd="$*"
	local cgiOut="$(MkTmpFile "${FUNCNAME}.${BASHPID}")"

	pushd "$siteDir" > /dev/null
	courseLeafPgm=$(GetCourseleafPgm | cut -d' ' -f1).cgi
	courseLeafDir=$(GetCourseleafPgm | cut -d' ' -f2)
	if [[ $courseLeafPgm == '.cgi' || $courseLeafDir == '' ]]; then Msg2 $T "$FUNCNAME: Could not find courseleaf executable"; fi
	dump -3  siteDir courseLeafPgm courseLeafDir cgiCmd
	[[ ! -x $courseLeafDir/$courseLeafPgm ]] && Msg2 $TT1 "$FUNCNAME: Could not find $courseLeafPgm in '$courseLeafDir' trying:\n^'$cgiCmd'\n^($calledLineNo)"

	## Run command
	cd $courseLeafDir
	{ ( ./$courseLeafPgm $cgiCmd ); } &> $cgiOut
	grepStr="$(ProtectedCall "grep -m 1 'ATJ error:' $cgiOut")"
	[[ $grepStr != '' ]] && Msg2 $TT1 "$FUNCNAME: ATJ errors were reported by the step.\n^^cgi cmd: '$cgiCmd'\n^^$grepStr"
	rm -f "$cgiOut"
	popd > /dev/null
	return 0
} #RunCourseLeafCgi
export -f RunCourseLeafCgi

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:15 CST 2017 - dscudiero - General syncing of dev to prod
## 04-06-2017 @ 08.36.18 - ("2.0.7")   - dscudiero - Add function name to messages
## 04-07-2017 @ 07.47.19 - ("2.0.10")  - dscudiero - General syncing of dev to prod
## 04-07-2017 @ 08.01.14 - ("2.0.11")  - dscudiero - Add Function name to output messages if we cannot find executable
## 04-07-2017 @ 08.11.17 - ("2.0.15")  - dscudiero - General syncing of dev to prod
## 04-07-2017 @ 08.23.31 - ("2.0.17")  - dscudiero - General syncing of dev to prod
## 04-07-2017 @ 08.29.53 - ("2.0.18")  - dscudiero - General syncing of dev to prod
## 04-07-2017 @ 08.46.26 - ("2.0.19")  - dscudiero - clean up how we process errors
## 05-04-2017 @ 13.18.23 - ("2.0.20")  - dscudiero - Restore from baclup
## 05-25-2017 @ 13.26.11 - ("2.0.21")  - dscudiero - Tweak how the tmpFile is assigned
