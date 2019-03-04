#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.58" # -- dscudiero -- Mon 03/04/2019 @ 07:29:02
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
	
	## snapshot table
		Verbose 1 "^Getting transactional field names..."
		SetFileExpansion 'off'
		sqlStmt="select * from sqlite_master where type=\"table\" and name=\"snapshots\""
		RunSql "$milestoneTransactionalDb" $sqlStmt
		SetFileExpansion
		[[ ${#resultSet[@]} -le 0 ]] && { Warning "Could not retrieve 'snapshots' table definition data from '$milestoneTransactionalDb'"; Goodbye; }
		unset tmFields
		tData="${resultSet[0]}";
		tData="${tData#*(}"; #(
		tData="${tData%)*}"; #
		ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$tData"
		for token in "${tmpArray[@]}"; do
			[[ ${token:0:1} == ' ' ]] && token="${token:1}"
	    	tsFields="$tsFields,${token%% *}"
		done
		tsFields=${tsFields:1}
		numtsFields=${#tmpArray[@]}
		IFS="$ifsSave"; unset tmpArray
		dump 1 -t2 "numtsFields tsFields"

	## Get the snapshot data
		Verbose 1 "^Getting the snapshot data..."
		sqlStmt="select $tsFields from snapshots"
		RunSql "$milestoneTransactionalDb" $sqlStmt
		[[ ${#resultSet[@]} -le 0 || ${resultSet[0]} == "" ]] && { Warning "Could not retrieve 'snapshots' data from '$milestoneTransactionalDb'"; Goodbye; }
		Verbose 1 "^^Found ${#resultSet[@]} snapshot records"
		for result in "${resultSet[@]}"; do
			key="${result%%|*}"
			snapshotsHash["$key"]="$result"
		done

	## milestone table
		SetFileExpansion 'off'
		sqlStmt="select * from sqlite_master where type=\"table\" and name=\"milestone\""
		RunSql "$milestoneTransactionalDb" $sqlStmt
		SetFileExpansion
		[[ ${#resultSet[@]} -le 0 ]] && { Warning "Could not retrieve 'milestone' table definition data from '$milestoneTransactionalDb'"; Goodbye; }
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
		[[ ${#resultSet[@]} -le 0 ]] && { Warning "Could not retrieve milestone data from '$milestoneTransactionalDb'"; Goodbye; }
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
	ParseArgs $*

	return 0
} ## Initialization

#============================================================================================================================================
declare -A snapshotsHash
declare -A milestoneHash
Initialization "$@"
Main "$@"
Goodbye 0 #'alert'

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 02-15-2019 @ 09:24:23 - 1.0.41 - dscudiero - Update to do load to a working table and the swap at the end
## 02-27-2019 @ 11:21:42 - 1.0.57 - dscudiero - Add/Remove debug statements
## 03-04-2019 @ 07:29:32 - 1.0.58 - dscudiero - Change Termiate messages to warnings
