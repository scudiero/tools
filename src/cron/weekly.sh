#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.16 # -- dscudiero -- 12/14/2016 @ 11:33:56.29
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import FindExecutable GetDefaultsData ParseArgsStd ParseArgs RunSql Msg2 Call
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
			Call 'reports' "client2DaySummaries -role 'support' -email 'dscudiero@leepfrog.com,jlindeman@leepfrog.com' $scriptArg"

			Msg2 "\n Tools Usage Report..."
			Call 'reports' "toolsUsage -email 'dscudiero@leepfrog.com,jlindeman@leepfrog.com' $scriptArgs"

			# Msg2 "\n QAstatus..."
			# Call 'reports' "qaStatus \'dscudiero@leepfrog.com,sjones@leepfrog.com\' $scriptArgs"

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
