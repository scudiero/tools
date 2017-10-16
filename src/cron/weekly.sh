#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.26 # -- dscudiero -- Mon 10/16/2017 @ 13:14:10.34
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import GetDefaultsData ParseArgsStd ParseArgs Msg3 FindExecutable
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
case $hostName in
	mojave)

		## Checks
			FindExecutable -sh -run checkForPrivateDevSites $scriptArgs

		## Weekly reports
			Msg3 \n Publishing Report...
			FindExecutable -sh -run reports publishing -email froggersupport@leepfrog.com $scriptArgs

			Msg3 \n Client 2 Day Summaries Report...
			FindExecutable -sh -run reports client2DaySummaries -role support -email froggersupport@leepfrog.com $scriptArg

			Msg3 \n QA Waiting Report...
			FindExecutable -sh -run reports qaWaiting -email sjones@leepfrog.com,mbruening@leepfrog.com,dscudiero@leepfrog.com $scriptArgs

			Msg3 \n Tools Usage Report...
			FindExecutable -sh -run reports toolsUsage -email dscudiero@leepfrog.com $scriptArgs

			Msg3 \n*** Reports -- Completed ***

		## Rollup logs
			FindExecutable -sh -run weeklyRollup $scriptArgs
			;;
	build5)
			;;
	build7)
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
