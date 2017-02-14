## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.11" # -- dscudiero -- 02/14/2017 @  9:43:51.35
#===================================================================================================
# Process semaphores
# Semaphore <mode> <key/name> <sleeptime>
#	mode = 	set <name>					-- Sets a semaphore for 'name' on the current host
#			check <name>				-- Checks to see if semaphore with 'name' is set in the current host
#			clear <keyid>				-- Clears semaphore with key = '$keyid'
#			waiton <name> <sleeptime>	-- waits on any semaphore set for 'name' on any host
#										   if name is 'self', then will wait on name '$myName'
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Semaphore {
	local mode=$1
	mode=$(Lower $mode)
	local keyId=$2
	[[ $keyId == 'self' ]] && keyId="$myName"
	local checkAllHosts=${3:-false}
	local sleepTime=5
	local sqlStmt result printMsg andClause

	[[ $checkAllHosts != false ]] && unset andClause || andClause="and hostName=\"$hostName\""
	dump -3 mode keyId checkAllHosts sleeptime andClause

	if [[ $mode = 'set' ]]; then
		sqlStmt="insert into $semaphoreInfoTable (keyId,processName,hostName,createdBy,createdOn) \
						 values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$startTime\")";
		RunSql2 $sqlStmt
		sqlStmt="select max(keyId) from $semaphoreInfoTable"
		RunSql2 $sqlStmt
		echo ${resultSet[0]}

	elif [[ $mode = 'getkeys' ]]; then
		sqlStmt="select keyId from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql2 $sqlStmt
 		if [[ ${#resultSet[@]} -ne 0 ]]; then
 			local retString
 			for result in ${resultSet[@]}; do
 				retString="$retString,$result"
 			done
 			echo ${retString:1}
 		fi

	elif [[ $mode = 'check' ]]; then
		sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql2 $sqlStmt
 		[[ ${resultSet[0]} -ne 0 ]] && echo false || echo true

	elif [[ $mode = 'clear' ]]; then
		sqlStmt="delete from $semaphoreInfoTable where keyId=\"$keyId\"";
		RunSql2 $sqlStmt

	elif [[ $mode = 'waiton' ]]; then
		count=1
		#echo 'Starting wait on' >> ~/stdout.txt
		while [[ $count -gt 0 ]]; do
			sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$keyId\"";
			RunSql2 $sqlStmt
 			[[ ${#resultSet[@]} -ne 0 ]] && count=${resultSet[0]} || count=0
 			[[ $count -gt 0 ]] && dump -3 -l -t count && sleep $sleepTime
		done
	fi

	return 0
} #Semaphore
export -f Semaphore

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:24 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Feb 14 09:44:10 CST 2017 - dscudiero - Added 'getKey' action to retrieve keys
