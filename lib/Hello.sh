## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.28" # -- dscudiero -- 01/11/2017 @  7:46:39.71
#===================================================================================================
# Common script start messaging
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Hello {
	[[ $quiet == true || $noHeaders == true || $secondaryMessagesOnly == true ]] && return 0
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	echo
	[[ $TERM == 'dumb' ]] && echo
	Msg2 "$(PadChar)"
	date=$(date)

	local checkName=$(logname 2>&1); rc=$?
	[[ $rc -gt 0 ]] && checkName="$LOGNAME"

	[[ "$version" = "" ]] && version=1.0.0
	Msg2 "${myName} ($version) -- Date: $(date +"%a") $(date +"%m-%d-%Y @ %H.%M.%S")"
	[[ "$myDescription" != "" ]] && Msg2 && Msg2 "$myDescription"
	[[ $checkName != $userName ]] && userStr="Real user $checkName, Tools user: $userName" || userStr="Tools user: $userName"
	Msg2 "$userStr, Host: $hostName, Database: $warehouseDb, PID: $$, PPID: $PPID"
	[[ -n $originalArgStr ]] && Msg2 "Arg String: '$originalArgStr'"

	# local myPath=$(dirname $(readlink -f $0))
	# [[ ${myPath:0:6} == '/home/' ]] && 	Msg2 "$(ColorW "*** Running from '$myPath'")"
	[[ ${0:0:6} == '/home/' ]] && 	Msg2 "$(ColorW "*** Running from a local directory")"

	[[ $testMode == true ]] && Msg2 "$(ColorW "*** Running in Testmode")"
	[[ "$DOIT" != ''  ]] && Msg2 "$(ColorW "*** The 'Doit' flag is turned off, changes not committed")"
	[[ "$informationOnlyMode" == true  ]] && Msg2 "$(ColorW "*** The 'informationOnly' flag is set, changes not committed")"
	[[ $userName != $checkName ]] && Msg2 "$(ColorW "*** Running as user $userName")"

	echo

	## Log Start in process log database
		if [[ $noLogInDb != true ]]; then
			myLogRecordIdx=$(ProcessLogger 'Start' "$myName")
			ProcessLogger 'Update' $myLogRecordIdx 'argString' "$originalArgStr"
		fi

	## Display script and tools news
		DisplayNews

	## If verbose level is 99 then show everything
		[[ $verboseLevel -eq 99 ]] && set -v

	return 0
} #Hello
export -f Hello

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 11:17:57 CST 2017 - dscudiero - If verboseLevel is 99 then set -xv
## Wed Jan  4 13:05:34 CST 2017 - dscudiero - change debug levels
## Wed Jan  4 13:34:00 CST 2017 - dscudiero - comment out the 'version=' line
## Fri Jan  6 09:30:22 CST 2017 - dscudiero - Added what database we are using to the header
## Wed Jan 11 07:51:01 CST 2017 - dscudiero - Switch to use ProcessLogger
