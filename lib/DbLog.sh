## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.10" # -- dscudiero -- 01/04/2017 @ 13:40:42.31
#===================================================================================================
# Write out a start record into the process log database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function DbLog {
	[[ $logInDb == false ]] && return 0

	local mode=$(Lower ${1:0:1}); shift || true
	[[ $mode == 'd' && $testmode == true ]] && mode='r' && unset myLogRecordIdx
	local idx argString sqlStmt myName epochEtime endTime elapSeconds eMin eSec
	if [[ $mode == 's' ]]; then # START
		myName=$1; shift || true
		argString="$*"
		[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
		[[ $allItems != '' && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
		sqlStmt="insert into $processLogTable (idx,name,hostName,userName,viaScripts,startTime,argString) \
				values(NULL,\"$myName\",\"$hostName\",\"$userName\",\"$calledViaScripts\",\"$startTime\",\"$argString\")"
		RunSql 'mysql' $sqlStmt
		sqlStmt="select max(idx) from $processLogTable"
		RunSql 'mysql' $sqlStmt
		echo ${resultSet[0]}
	elif [[ $mode == 'd' ]]; then # UPDATE DATA
		idx=$1; shift || true
		[[ $idx = '' ]] && return 0
		argString="$*"
		[[ $informationOnlyMode == true ]] && argString="${argString}, informationOnlyMode"
		[[ $allItems != '' && $(Contains "$argString" 'allItems') != true ]] && argString="${argString}, AllItems"
		sqlStmt="update $processLogTable set data=\"$argString\" where idx=$idx"
		RunSql 'mysql' $sqlStmt
	elif [[ $mode == 'x' ]]; then # UPDATE EXITCODE
		idx=$1; shift || true
		[[ $idx = '' ]] && return 0
		argString="$*"
		sqlStmt="update $processLogTable set exitCode=\"$argString\" where idx=$idx"
		RunSql 'mysql' $sqlStmt
	elif [[ $mode == 'e' ]]; then # END
		idx=$1
		[[ $idx = '' ]] && return 0
		epochEtime=$(date +%s)
		endTime=$(date '+%Y-%m-%d %H:%M:%S')
		elapSeconds=$(( epochEtime - epochStime ))
		eHr=$(( elapSeconds / 3600 ))
		elapSeconds=$(( elapSeconds - eHr * 3600 ))
		eMin=$(( elapSeconds / 60 ))
		elapSeconds=$(( elapSeconds - eMin * 60 ))
		eSec=$elapSeconds
		elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $eSec)
		sqlStmt="update $processLogTable set endTime=\"$startTime\",elapsedTime=\"$elapTime\" where idx=$idx"
		RunSql 'mysql' $sqlStmt
	elif [[ $mode == 'r' ]]; then # REMOVE
		idx=$1; shift || true
		[[ $idx = '' ]] && return 0
		sqlStmt="delete from $processLogTable where idx=$idx"
		[[ $idx != '' ]] && RunSql 'mysql' $sqlStmt
	fi

	return 0
} #DbLog

function dbLog { DbLog "$*"; }

export -f DbLog
export -f dbLog

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:13 CST 2017 - dscudiero - General syncing of dev to prod
