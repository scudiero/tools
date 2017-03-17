#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.22 # -- dscudiero -- 03/17/2017 @ 11:23:12.31
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import GetDefaultsData ParseArgsStd ParseArgs Msg2 FindExecutable Call
originalArgStr="$*"

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
scriptArgs="$*"

#========================================================================================================================
# Main
#========================================================================================================================
case "$hostName" in
	mojave)
		## Weekly reports
			Msg2 "\n Publishing Report..."
			Call 'reports' "publishing -email 'froggersupport@leepfrog.com' $scriptArgs"

			Msg2 "\n Client 2 Day Summaries Report..."
			Call 'reports' "client2DaySummaries -role 'support' -email 'froggersupport@leepfrog.com' $scriptArg"

			Msg2 "\n QA Waiting Report..."
			Call 'reports' "qaWaiting -email 'sjones@leepfrog.com,mbruening@leepfrog.com,dscudiero@leepfrog.com' $scriptArgs"

			Msg2 "\n Tools Usage Report..."
			Call 'reports' "toolsUsage -email 'dscudiero@leepfrog.com' $scriptArgs"

			Msg2 "\n*** Reports -- Completed ***"

		## Rollup logs
			Call 'weeklyRollup' "$scriptArgs"
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
