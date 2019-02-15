#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.41" # -- dscudiero -- Fri 02/15/2019 @ 09:22:49
#=======================================================================================================================
#= Description #========================================================================================================
#
#
#=======================================================================================================================
TrapSigs 'on'
originalArgStr="$*"
scriptDescription=""

function Main() {

	table="$milestonesInfoTable"
	workTable="${table}Work"

	## Create a working table
	sqlStmt="drop table if exists $workTable"
	RunSql $sqlStmt
	sqlStmt="create table $workTable like $table"
	RunSql $sqlStmt
	
	Verbose 1 "^Getting transactional field names"
	## snapshot table
		SetFileExpansion 'off'
		sqlStmt="select * from sqlite_master where type=\"table\" and name=\"snapshots\""
		RunSql "$milestoneTransactionalDb" $sqlStmt
		SetFileExpansion
		[[ ${#resultSet[@]} -le 0 ]] && Terminate "Could not retrieve 'snapshots' table definition data from '$milestoneTransactionalDb'"
		unset tmFields
		tData="${resultSet[0]#*(}"; tData="${tData%)*}" 
		ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$tData"
		for token in "${tmpArray[@]}"; do
			[[ ${token:0:1} == ' ' ]] && token="${token:1}"
	    	tsFields="$tsFields,${token%% *}"
		done
		tsFields=${tsFields:1}
		numtsFields=${#tmpArray[@]}
		IFS="$ifsSave"; unset tmpArray
	## Get the snapshot data
		sqlStmt="select $tsFields from snapshots"
		RunSql "$milestoneTransactionalDb" $sqlStmt
		[[ ${#resultSet[@]} -le 0 ]] && Terminate "Could not retrieve 'snapshots' data from '$milestoneTransactionalDb'" 
		Verbose 1 "^^Found ${#resultSet[@]} snapshot records"
		for result in "${resultSet[@]}"; do
			snapshotsHash["${result%%|*}"]="$result"
		done

	## milestone table
		SetFileExpansion 'off'
		sqlStmt="select * from sqlite_master where type=\"table\" and name=\"milestone\""
		RunSql "$milestoneTransactionalDb" $sqlStmt
		SetFileExpansion
		[[ ${#resultSet[@]} -le 0 ]] && Terminate "Could not retrieve 'milestone' table definition data from '$milestoneTransactionalDb'"
		unset tmFields
		tData="${resultSet[0]#*(}"; tData="${tData%)*}" 
		ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$tData"
		for token in "${tmpArray[@]}"; do
			[[ ${token:0:1} == ' ' ]] && token="${token:1}"
	    	tmFields="$tmFields,${token%% *}"
		done
		tmFields=${tmFields:1}
		numtmFields=${#tmpArray[@]}
		IFS="$ifsSave"; unset tmpArray
	## Get the milestone data
		sqlStmt="select $tmFields from milestone"
		RunSql "$milestoneTransactionalDb" $sqlStmt
		[[ ${#resultSet[@]} -le 0 ]] && Terminate "Could not retrieve milestone data from '$milestoneTransactionalDb'"
		Verbose 1 "^^Found ${#resultSet[@]} milestone records"
		## Loop through milestones
		for result in "${resultSet[@]}"; do
			dump -1 -n result
			## Get the snapshot data for this milestone
				snapshotData="${snapshotsHash["${result%%|*}"]}"; snapshotData="${snapshotData#*|}"
				client="${snapshotData%%|*}"; snapshotData="${snapshotData#*|}"
				project="${snapshotData%%|*}"; snapshotData="${snapshotData#*|}"
				modTime="${snapshotData%%|*}"; snapshotData="${snapshotData#*|}"
				archived="$snapshotData"; [[ -z $archived || $archived == '' ]] && archived='N'
				values="NULL,${result%%|*},\"$client\",\"$project\",\"$modTime\",\"$archived\""
				dump -1 -t client project modTime archived
			## Parse the milestone data
				result="${result#*|}"
				dump -1 -t result
				rank="${result%%|*}"; result="${result#*|}"
				name="${result%%|*}"; result="${result#*|}"
				label="${result%%|*}"; result="${result#*|}"
				date="${result%%|*}"; result="${result#*|}"
				complete="${result%%|*}"; result="${result#*|}"
				dump -1 -t rank name label date complete
			## build and insert the record
				values="$values,\"$rank\",\"$name\",\"$label\",\"$date\",\"$complete\""
				sqlStmt="insert into $workTable values($values)"
				RunSql $sqlStmt
		done

	## If all is OK, then swap the working table and real table
			sqlStmt="select count(*) from $workTable"
			RunSql $sqlStmt
			if [[ ${resultSet[0]} -ne 0 ]]; then
				sqlStmt="drop table if exists ${table}"
				RunSql $sqlStmt
				sqlStmt="rename table $workTable to $table"
				RunSql $sqlStmt
			else
				Error "'$workTable' table is empty"
				sqlStmt="drop table if exists  $workTable"
				RunSql $sqlStmt
			fi	

	return 0
} ## Main

	#=======================================================================================================================
	# Initialization
	#=======================================================================================================================
	function Initialization {
		myIncludes="WriteChangelogEntry"
		Import "$standardInteractiveIncludes $myIncludes"

		tmpFile=$(mkTmpFile)
		GetDefaultsData -f $myName

		## Parse defaults fast
		while [[ $# -gt 0 ]]; do
		    [[ $1 =~ ^-v.$ ]] && { verboseLevel=${1:2}; }
		    shift 1 || true
		done

		return 0
	} ## Initialization

#============================================================================================================================================
declare -A snapshotsHash
declare -A milestoneHash
Initialization "#@"
Main "$@"
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 02-15-2019 @ 09:24:23 - 1.0.41 - dscudiero - Update to do load to a working table and the swap at the end
