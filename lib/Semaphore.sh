## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.23" # -- dscudiero -- 02/14/2017 @ 10:33:00.69
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
	local mode=${1:-'check'}
	mode=$(Lower $mode)
	local keyId=$2
	[[ $keyId == 'self' ]] && keyId="$myName"
	local checkAllHosts=${3:-false}
	local sleepTime=5
	local timeOutCnt waitCnt sqlStmt result printMsg andClause whereClause
	let timeOutCnt=$sleepTime*60/5*60
	[[ $checkAllHosts != false ]] && unset andClause || andClause="and hostName=\"$hostName\""
	dump -3 mode keyId checkAllHosts sleeptime andClause

	if [[ ${mode:0:1} == 's' ]]; then  ## 'set'
		sqlStmt="insert into $semaphoreInfoTable (keyId,processName,hostName,createdBy,createdOn) \
						 values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$startTime\")";
		RunSql2 $sqlStmt
		sqlStmt="select max(keyId) from $semaphoreInfoTable"
		RunSql2 $sqlStmt
		echo ${resultSet[0]}

	elif [[ ${mode:0:1} == 'g' ]]; then  ## 'getkeys'
		sqlStmt="select keyId from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql2 $sqlStmt
 		if [[ ${#resultSet[@]} -ne 0 ]]; then
 			local retString
 			for result in ${resultSet[@]}; do
 				retString="$retString,$result"
 			done
 			echo ${retString:1}
 		fi

	elif [[ ${mode:0:2} == 'ch' ]]; then  ## 'check'
		sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql2 $sqlStmt
 		[[ ${resultSet[0]} -ne 0 ]] && echo false || echo true

	elif [[ ${mode:0:2} == 'cl' ]]; then  ## 'clear'
		sqlStmt="delete from $semaphoreInfoTable where keyId=\"$keyId\"";
		RunSql2 $sqlStmt

	elif [[ ${mode:0:1} == 'w' ]]; then  ## 'waiton'
		count=1
		#echo 'Starting wait on' >> ~/stdout.txt
		while [[ $count -gt 0 ]]; do
			[[ $(IsNumeric $keyId) == true ]] && whereClause="keyId=\"$keyId\"" || whereClause="processName=\"$keyId\""
			sqlStmt="select count(*) from $semaphoreInfoTable where $whereClause";
			RunSql2 $sqlStmt
 			[[ ${#resultSet[@]} -ne 0 ]] && count=${resultSet[0]} || count=0
 			[[ $count -gt 0 ]] && dump -3 -l -t count && ((waitCnt++)) && sleep $sleepTime
 			[[ $waitCnt -gt $timeOutCnt ]] && Terminate "$FUNCNAME - Wait action timed out waiting on '$whereClause' after $timeOutCnt iterations."
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
## Tue Feb 14 10:47:30 CST 2017 - dscudiero - Added time out counter for waiton action
