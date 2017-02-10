#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.20 # -- dscudiero -- 02/10/2017 @ 14:58:31.84
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
			Call 'reports' "client2DaySummaries -role 'support' -email 'dscudiero@leepfrog.com' $scriptArg"

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
