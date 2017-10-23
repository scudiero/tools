#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.35 # -- dscudiero -- Mon 10/23/2017 @ 11:42:11.03
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="ParseArgsStd FindExecutable StringFunctions"
Import "$standardIncludes $myIncludes"
originalArgStr=$*

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
scriptArgs=$*

#========================================================================================================================
# Main
#========================================================================================================================
case "$hostName" in
	mojave)
		## Checks
			Msg3 "Starting Checks"
			(( indentLevel++ )) || true
			FindExecutable -sh -run checkForPrivateDevSites $scriptArgs | Indent
			(( indentLevel-- )) || true
			Msg3 "Checks Completed"
		## Weekly reports
			Msg3 "Starting Reports"
			(( indentLevel++ )) || true

			Msg3 "^Publishing Report..."
			(( indentLevel++ )) || true
			FindExecutable scriptsAndReports -sh -run reports publishing -email froggersupport@leepfrog.com $scriptArgs | Indent
			(( indentLevel-- )) || true

			Msg3 "^Client 2 Day Summaries Report..."
			(( indentLevel++ )) || true
			FindExecutable scriptsAndReports -sh -run reports client2DaySummaries -role support -email froggersupport@leepfrog.com $scriptArg | Indent
			(( indentLevel-- )) || true

			Msg3 "^QA Waiting Report..."
			(( indentLevel++ )) || true
			FindExecutable scriptsAndReports -sh -run reports qaWaiting -email sjones@leepfrog.com,mbruening@leepfrog.com,dscudiero@leepfrog.com $scriptArgs | Indent
			(( indentLevel-- )) || true

			Msg3 "^Tools Usage Report..."
			(( indentLevel++ )) || true
			FindExecutable scriptsAndReports -sh -run reports toolsUsage -email dscudiero@leepfrog.com $scriptArgs | Indent
			(( indentLevel-- )) || true

			Msg3 "^Reports Completed"

		## Rollup logs
			Msg3 "Starting Scripts"
			(( indentLevel++ )) || true
			FindExecutable weeklyRollup -sh -run $scriptArgs | Indent
			(( indentLevel-- )) || true
			Msg3 "Starting Scripts"
			;;
	build5)
			;;
	build7)
		## Checks
			Msg3 "Starting Checks"
			(( indentLevel++ )) || true
			FindExecutable -sh -run checkForPrivateDevSites $scriptArgs | Indent
			(( indentLevel-- )) || true
			Msg3 "Checks Completed"	
			;;
esac

#========================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Jan  5 14:50:18 CST 2017 - dscudiero - Switch to use RunSql2
## Tue Jan 17 07:42:31 CST 2017 - dscudiero - comment out some reports
## Fri Feb 10 14:58:55 CST 2017 - dscudiero - add 2 day summary reports back
## Thu Mar  9 07:52:54 CST 2017 - dscudiero - send the 2 day summary report to froggersupport
## Fri Mar 17 11:23:42 CDT 2017 - dscudiero - Added qaWaiting report
## 04-05-2017 @ 07.06.09 - (2.1.23)    - dscudiero - Add checkForPrivateDevSites
## 10-11-2017 @ 10.37.52 - (2.1.25)    - dscudiero - Switch to use FindExecutable -run
## 10-16-2017 @ 13.14.42 - (2.1.26)    - dscudiero - Tweak call to weekelyRollup
## 10-23-2017 @ 10.44.28 - (2.1.29)    - dscudiero - Refactor all calls
## 10-23-2017 @ 11.41.15 - (2.1.33)    - dscudiero - Fix problem incrementing indentLevel
## 10-23-2017 @ 11.41.52 - (2.1.34)    - dscudiero - Cosmetic/minor change
## 10-23-2017 @ 11.42.15 - (2.1.35)    - dscudiero - Cosmetic/minor change
