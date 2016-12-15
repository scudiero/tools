#=======================================================================================================================
# DO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.23 # -- dscudiero -- 11/18/2016 @ 14:10:01.47
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye
originalArgStr="$*"

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
[[ $warehouseDb != 'warehouseDev' ]] && mySqlConnectString="$(sed s"/warehouse/$warehouseDev/"g <<< $mySqlConnectString)"
export warehouseDb='warehouseDev'

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
echo "Starting testCron"
GetDefaultsData $myName
ParseArgsStd

Msg2 "\n Publishing Report..."
Call 'reports' "publishing -email 'dscudiero@leepfrog.com' $scriptArgs"

Msg2 "\n Client 2 Day Summaries Report..."
Call 'reports' "client2DaySummaries -role 'support' -email 'dscudiero@leepfrog.com' $scriptArg"

Msg2 "\n Tools Usage Report..."
Call 'reports' "toolsUsage -email 'dscudiero@leepfrog.com' $scriptArgs"


#========================================================================================================================
# Main
#========================================================================================================================
case "$hostName" in
	mojave)

			# ## Set a semaphore
			# 	sqlStmt="truncate $semaphoreInfoTable"
			# 	RunSql 'mysql' $sqlStmt
			# 	sqlStmt="insert into $semaphoreInfoTable values(NULL,\"$myName\",NULL,NULL,NULL)"
			# 	RunSql 'mySql' $sqlStmt
			# 	echo start buildClientInfoTable

			:
			;;
	*)
			# ## Check semaphore, wait for truncate to be done on mojave
			# 	sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$myName\""
			# 	while true; do
			# 		RunSql 'mySql' $sqlStmt
			# 		[[ ${resultSet[@]} -eq 0 ]] && break
			# 		echo Waiting
			# 		sleep 30
			# 	done
			# 	echo start buildSiteInfoTable

			:
			;;
esac

#========================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait

echo "$myName Done..."
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
