## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.41" # -- dscudiero -- Thu 10/19/2017 @  9:36:39.56
#===================================================================================================
# Common script start messaging
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Hello {
	[[ $quiet == true || $noHeaders == true || $secondaryMessagesOnly == true ]] && return 0
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear

	includes="ProcessLogger DisplayNews"
	Import "$includes"
	
	echo
	[[ $TERM == 'dumb' ]] && echo
	[[ $noBanners != true ]] && Msg3 "$(PadChar)"
	date=$(date)

	local checkName=$(logname 2>&1); rc=$?
	[[ $rc -gt 0 ]] && checkName="$LOGNAME"

	[[ "$version" = "" ]] && version=1.0.0
	Msg3 "${myName} ($version) -- Date: $(date +"%a") $(date +"%m-%d-%Y @ %H.%M.%S")"
	[[ $noBanners != true && "$myDescription" != "" ]] && Msg3 && Msg3 "$myDescription"
	[[ $checkName != $userName ]] && userStr="Real user $checkName, Tools user: $userName" || userStr="Tools user: $userName"
	[[ $noBanners != true ]] && Msg3 "$userStr, Host: $hostName, Database: $warehouseDb, PID: $$, PPID: $PPID"
	[[ -n $(Trim "$originalArgStr") ]] && Msg3 "Arg String: '$originalArgStr'"

	# echo "\$0 = $0"
	# [[ ${0:0:6} == '/home/' ]] && Msg3 "$(ColorW "*** Running from a local directory")"

	[[ $testMode == true ]] && Msg3 "$(ColorW "*** Running in Testmode ***")"
	[[ "$DOIT" != ''  ]] && Msg3 "$(ColorW "*** The 'Doit' flag is turned off, changes not committed")"
	[[ "$informationOnlyMode" == true  ]] && Msg3 "$(ColorW "*** The 'informationOnly' flag is set, changes not committed")"
	[[ $userName != $checkName ]] && Msg3 "$(ColorW "*** Running as user $userName ***")"

	echo
	## Log Start in process log database
		if [[ $noLogInDb != true ]]; then
			myLogRecordIdx=$(ProcessLogger 'Start' "$myName")
			ProcessLogger 'Update' $myLogRecordIdx 'argString' "$originalArgStr"
		fi

	## Display script and tools news
		#DisplayNews

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
## Fri Jan 20 13:20:56 CST 2017 - dscudiero - Do not show arguments if they are blank
## 06-02-2017 @ 15.24.54 - ("2.0.31")  - dscudiero - Remove the running local message
## 08-31-2017 @ 15.48.35 - ("2.0.32")  - dscudiero - Tweak messaging
## 09-25-2017 @ 09.01.51 - ("2.0.34")  - dscudiero - Switch to Msg3
## 10-02-2017 @ 15.31.43 - ("2.0.38")  - dscudiero - commento out DisplayNews
## 10-03-2017 @ 13.40.27 - ("2.0.39")  - dscudiero - remove debug stuff
## 10-17-2017 @ 14.08.11 - ("2.0.40")  - dscudiero - Added noBanners option to streamline output in batch
## 10-19-2017 @ 09.38.34 - ("2.0.41")  - dscudiero - Added -noBanner option to limit outout
