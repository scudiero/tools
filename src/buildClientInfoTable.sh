#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.3.86 # -- dscudiero -- 01/06/2017 @  7:41:08.67
#=======================================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Sync client warehouse and transactional tables"

#=======================================================================================================================
# Synchronize client data from the transactional sqlite db and the data warehouse
#=======================================================================================================================
#=======================================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
fork=false
processNotify=30
forkCntr=0; cntr=0;
[[ $fork == true ]] && forkStr='fork' || unset forkStr

## Find the helper script location
workerScript='insertClientInfoRec'; useLocal=true
FindExecutable "$workerScript" 'std' 'bash:sh' ## Sets variable executeFile
workerScriptFile="$executeFile"
addedCalledScriptArgs="-secondaryMessagesOnly"

## Local variable initialization
GetDefaultsData $myName
unset tokens ignoreShares ignoreSites
if [[ $ignoreList != '' ]]; then
	tokens+=("$(cut -d' ' -f1 <<< $ignoreList)")
	#tokens+=("$(cut -d' ' -f2 <<< $ignoreList)")
	for token in "${tokens[@]}"; do
		tokenVar=$(cut -d ':' -f1 <<< $token)
		tokenVal=$(cut -d ':' -f2- <<< $token)
		eval $tokenVar="$tokenVal"
	done
fi

[[ $testMode == true ]] && export warehousedb='warehouseDev'

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
ParseArgsStd
Hello
useClientInfoTable="${clientInfoTable}New"
Msg2 "Database: $warehouseDb"
Msg2 "Table: $useClientInfoTable"

#=======================================================================================================================
# Local Subs
#=======================================================================================================================

#=======================================================================================================================
# Main
#=======================================================================================================================
## Get list of clients from the transactional system
	if [[ $client != '' ]]; then
		clients+=($client);
	else
		sqlStmt="select clientcode from clients where is_active = \"Y\""
		RunSql2 "$contactsSqliteFile" "$sqlStmt"
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate"No records returned from clientcode query"
		for result in "${resultSet[@]}"; do
			clients+=($result)
		done
	fi

## Create a temporary copy of the clients table, load new data to that table
	sqlStmt="drop table if exists ${clientInfoTable}Bak"
	RunSql2 $sqlStmt
	sqlStmt="drop table if exists $useClientInfoTable"
	RunSql2 $sqlStmt
	sqlStmt="create table $useClientInfoTable like ${clientInfoTable}"
	RunSql2 $sqlStmt

## Loop through clients
	clientCntr=0
	numClients=${#clients[@]}
	Msg2 "Found $numClients clients..."
	forkCntr=1;
	## Loop through the server/share directories
		for client in "${clients[@]}"; do
			(( clientCntr += 1 ))
			if [[ $(Contains ",$ignoreList," ",$client,") == true ]]; then
				[[ $batchMode != true ]] && Msg2 "^Skipping '$client' is in the ignore list."
				continue
			fi
			unset msgPrefix
			[[ $fork == true ]] && msgPrefix='Forking off' || msgPrefix='Processing'
			[[ $batchMode != true ]] && Msg2 "^$msgPrefix $client ($clientCntr / ${#clients[@]})..."
			Call "$workerScriptFile" "$forkStr" "$addedCalledScriptArgs"
			rc=$?
			(( forkCntr+=1 ))
			## Wait for forked process to finish, only run maxForkedProcesses at a time
			if [[ $fork == true && $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
				[[ $batchMode != true ]] && Msg2 "^Waiting on forked processes...\n"
				wait
			fi
			[[ $fork != true && $(($clientCntr % processNotify)) -eq 0 ]] && Msg2 "\n^*** Processed $clientCntr out of $numClients\n"
		done

## Wait for all the forked tasks to stop
	if [[ $fork == true ]]; then
		[[ $batchMode != true ]] && Msg2 "^Waiting for all forked processes to complete..."
		wait
	fi

## Swap client tables
	[[ $batchMode != true ]] && Msg2 "^Swapping databases ..."
	sqlStmt="select count{*) from ${clientInfoTable}New"
	RunSql2
	[[ ${#resultSet[@]} -eq 0 ]] &&  Terminate "New clients table has zero rows, keeping original"

	sqlStmt="rename table $clientInfoTable to ${clientInfoTable}Bak"
	RunSql2 $sqlStmt
	[[ $batchMode != true ]] && Msg2 "^^$clientInfoTable --> ${clientInfoTable}Bak"
	sqlStmt="rename table ${clientInfoTable}New to $clientInfoTable"
	RunSql2 $sqlStmt
	[[ $batchMode != true ]] && Msg2 "^^${clientInfoTable}New --> $clientInfoTable"

#=======================================================================================================================
# Done
#=======================================================================================================================
Goodbye 0 'alert'

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Mon Jun  6 13:11:14 CDT 2016 - dscudiero - Renamed and Re-factored
## Mon Jun  6 13:27:36 CDT 2016 - dscudiero - General syncing of dev to prod
## Tue Jul 12 07:10:42 CDT 2016 - dscudiero - Add override parameters to callPgm
## Thu Jan  5 12:37:46 CST 2017 - dscudiero - refactored to create a new table, insert data and then rename if successful
## Thu Jan  5 12:53:22 CST 2017 - dscudiero - remove debug statements
## Thu Jan  5 12:56:56 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 13:40:11 CST 2017 - dscudiero - removed debug code
## Thu Jan  5 14:00:07 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan  6 07:26:18 CST 2017 - dscudiero - Fix syntax error
## Fri Jan  6 07:41:30 CST 2017 - dscudiero - Add Messages for the swap db process
