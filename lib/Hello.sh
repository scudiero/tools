## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.59" # -- dscudiero -- Mon 04/01/2019 @ 11:05:57
#===================================================================================================
# Common script start messaging
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Hello {
	myIncludes="StringFunctions RunSql"
	Import "$standardIncludes $myIncludes"

	[[ $quiet == true || $noHeaders == true || $secondaryMessagesOnly == true ]] && return 0
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear

	includes="ProcessLogger DisplayNews"
	Import "$includes"
	
	[[ $batchMode != true ]] && echo
	[[ $TERM == 'dumb' ]] && echo
	[[ $noBanners != true ]] && Msg "$(PadChar)"
	date=$(date)

	local checkName=$(logname 2>&1); rc=$?
	[[ $rc -gt 0 ]] && checkName="$LOGNAME"

	[[ "$version" = "" ]] && version=1.0.0
	Msg "${myName} ($version) -- Date: $(date +"%a") $(date +"%m-%d-%Y @ %H.%M.%S")"

	local sqlStmt="select supported from $scriptsTable where name = \"$myName\""
	RunSql $sqlStmt
	[[ -z ${resultSet[0]} && $batchMode != true ]] && Warning "This script is no longer supported"	

	[[ $noBanners != true && "$myDescription" != "" ]] && Msg && Msg "$myDescription"
	[[ $checkName != $userName ]] && userStr="Real user $checkName, Tools user: $userName" || userStr="Tools user: $userName"
	[[ $noBanners != true ]] && Msg "$userStr, Host: $hostName, Database: $warehouseDb, PID: $$, PPID: $PPID"
	[[ -n $(Trim "$originalArgStr") ]] && Msg "Arg String: '$originalArgStr'"

	[[ $USEDEV == true ]] && Msg "$(ColorW "*** Running from the 'toolsDev' directory")"
	[[ $USELOCAL == true ]] && Msg "$(ColorW "*** Running from your local tools directory")"

	[[ $testMode == true ]] && Msg "$(ColorW "*** Running in Testmode ***")"
	[[ "$DOIT" != ''  ]] && Msg "$(ColorW "*** The 'Doit' flag is turned off, changes not committed")"
	[[ "$informationOnlyMode" == true  ]] && Msg "$(ColorW "*** The 'informationOnly' flag is set, changes not committed")"
	[[ $userName != $checkName ]] && Msg "$(ColorW "*** Running as user $userName ***")"

	[[ $batchMode != true ]] && echo
	## Log Start in process log database
		if [[ $noLogInDb != true ]]; then
			myLogRecordIdx=$(ProcessLogger 'Start' "$myName")
			ProcessLogger 'Update' $myLogRecordIdx 'argString' "$originalArgStr"
		fi

	# ## Display script and tools news
	# 	DisplayNews

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
## 09-25-2017 @ 09.01.51 - ("2.0.34")  - dscudiero - Switch to Msg
## 10-02-2017 @ 15.31.43 - ("2.0.38")  - dscudiero - commento out DisplayNews
## 10-03-2017 @ 13.40.27 - ("2.0.39")  - dscudiero - remove debug stuff
## 10-17-2017 @ 14.08.11 - ("2.0.40")  - dscudiero - Added noBanners option to streamline output in batch
## 10-19-2017 @ 09.38.34 - ("2.0.41")  - dscudiero - Added -noBanner option to limit outout
## 10-19-2017 @ 12.45.29 - ("2.0.42")  - dscudiero - Add StringFunctions to the includes slist
## 11-01-2017 @ 08.02.37 - ("2.0.43")  - dscudiero - Cosmetic/minor change
## 11-09-2017 @ 07.26.29 - ("2.0.44")  - dscudiero - Add Debug statements
## 11-09-2017 @ 11.09.05 - ("2.0.46")  - dscudiero - Added a runing from local message
## 03-23-2018 @ 16:47:59 - 2.0.51 - dscudiero - Msg3 -> Msg
## 04-18-2018 @ 09:35:01 - 2.0.52 - dscudiero - Added USEDEV message
## 11-06-2018 @ 07:42:00 - 2.0.56 - dscudiero - Add not supported message
## 12-27-2018 @ 07:21:29 - 2.0.57 - dscudiero - Comment out displaying news
## 04-01-2019 @ 11:06:11 - 2.0.59 - dscudiero - Tweak messaging
