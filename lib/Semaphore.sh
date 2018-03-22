## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.26" # -- dscudiero -- Thu 03/22/2018 @ 13:11:08.01
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
	myIncludes="StringFunctions RunSql"
	Import "$myIncludes"

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
		RunSql $sqlStmt
		sqlStmt="select max(keyId) from $semaphoreInfoTable"
		RunSql $sqlStmt
		echo ${resultSet[0]}

	elif [[ ${mode:0:1} == 'g' ]]; then  ## 'getkeys'
		sqlStmt="select keyId from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql $sqlStmt
 		if [[ ${#resultSet[@]} -ne 0 ]]; then
 			local retString
 			for result in ${resultSet[@]}; do
 				retString="$retString,$result"
 			done
 			echo ${retString:1}
 		fi

	elif [[ ${mode:0:2} == 'ch' ]]; then  ## 'check'
		sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$keyId\" $andClause";
		RunSql $sqlStmt
 		[[ ${resultSet[0]} -ne 0 ]] && echo false || echo true

	elif [[ ${mode:0:2} == 'cl' ]]; then  ## 'clear'
		sqlStmt="delete from $semaphoreInfoTable where keyId=\"$keyId\"";
		RunSql $sqlStmt

	elif [[ ${mode:0:1} == 'w' ]]; then  ## 'waiton'
		count=1
		#echo 'Starting wait on' >> ~/stdout.txt
		while [[ $count -gt 0 ]]; do
			[[ $(IsNumeric $keyId) == true ]] && whereClause="keyId=\"$keyId\"" || whereClause="processName=\"$keyId\""
			sqlStmt="select count(*) from $semaphoreInfoTable where $whereClause";
			RunSql $sqlStmt
 			[[ ${#resultSet[@]} -ne 0 ]] && count=${resultSet[0]} || count=0
 			[[ $count -gt 0 ]] && dump -3 -l -t count && ((waitCnt++)) && sleep $sleepTime
 			[[ $waitCnt -gt $timeOutCnt ]] && Terminate "$FUNCNAME - Wait action timed out waiting on '$whereClause' after $timeOutCnt iterations."
		done
	fi

	return 0
} #Semaphore
export -f Semaphore

function CheckSemaphore {
	##==============================================================================================
	local callPgmName=$1; shift
	local waitOn=$1; shift
	local lib=$1; shift
	local okToRun okToRunWaiton semaphoreId
	##==============================================================================================

	unset okToRun okToRunWaiton
	okToRun=$(Semaphore 'check' $callPgmName)
	## Check to see if we are running or any waitOn process are running
	[[ $okToRun == false && $(Contains ",$waitOn," ',self,') != true ]] && Terminate "CallPgm: Another instance of this script ($callPgmName) is currently running.\n"
	if [[ $waitOn != '' ]]; then
		for pName in $(echo $waitOn | tr ',' ' '); do
			waitonMode=$(cut -d':' -f2 <<< $pName)
			pName=$(cut -d':' -f1 <<< $pName)
			[[ $(Lower $waitonMode) == 'g' ]] && checkAllHosts='checkAllHosts' || unset checkAllHosts
			okToRun=$(Semaphore 'check' $pName $checkAllHosts)
			if [[ $okToRun == false ]]; then
				[[ $batchMode != true ]] && Msg "CallPgm: Waiting for process '$pName' to finish..."
				Semaphore 'waiton' "$pName" $checkAllHosts
			fi
		done
	fi
	## Set our semaphore
	semaphoreId=$(Semaphore 'set')

	echo $semaphoreId
	return 0
} #CheckSemaphore
export -f CheckSemaphore


#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:24 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Feb 14 09:44:10 CST 2017 - dscudiero - Added 'getKey' action to retrieve keys
## Tue Feb 14 10:47:30 CST 2017 - dscudiero - Added time out counter for waiton action
## 10-20-2017 @ 12.42.16 - ("2.0.25")  - dscudiero - Add StringFunctions to the included list
## 03-22-2018 @ 13:16:48 - 2.0.26 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
