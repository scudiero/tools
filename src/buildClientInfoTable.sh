#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.3.78 # -- dscudiero -- 01/05/2017 @ 12:35:32.40
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

echo -e "\nHERE 0\n"

#=======================================================================================================================
# Local Subs
#=======================================================================================================================

#=======================================================================================================================
# Main
#=======================================================================================================================
## Get list of clients
	if [[ $client != '' ]]; then
		clients+=($client);
	else
		sqlStmt="select clientcode from clients where is_active = \"Y\""
		RunSql2 "$contactsSqliteFile" "$sqlStmt"
		[[ ${#resultSet[@]} -eq 0 ]] && Msg2 $T "No records returned from clientcode query"
		for result in "${resultSet[@]}"; do
			clients+=($result)
		done
	fi

dump warehousedb
Quit

## Create a temporary copy of the clients table, load new data to that table
	sqlStmt="drop table if exists ${clientInfoTable}Bak"
	RunSql2 $sqlStmt
	sqlStmt="drop table if exists ${clientInfoTable}New"
	RunSql2 $sqlStmt
	sqlStmt="create table ${clientInfoTable}New like ${clientInfoTable}"
	RunSql2 $sqlStmt
	useClientInfoTable="${clientInfoTable}New"

## Loop through clients
	clientCntr=0
	numClients=${#clients[@]}
	Msg2 "Found $numClients clients..."
	forkCntr=1;
	## Loop through the server/share directories
		for client in "${clients[@]}"; do
			(( clientCntr += 1 ))
			if [[ $(Contains ",$ignoreList," ",$client,") == true ]]; then
				[ $batchMode != true ]] && Msg2 "^Skipping '$client' is in the ignore list."
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
				[[ $batchMode != true ]] && Msg2 "^Waiting on forked processes, processed $forkCntr of $processedSiteCntr ...\n"
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
	sqlStmt="select count{*) from ${clientInfoTable}New"
	RunSql2
	[[ $#resultSet[@]} -eq 0 ]] &&  Terminate "New clients table has zero rows, keeping original"

	sqlStmt="rename table $clientInfoTable to ${clientInfoTable}Bak"
	RunSql2 $sqlStmt
	sqlStmt="rename table ${clientInfoTable}New to $clientInfoTable"
	RunSql2 $sqlStmt

	RunSql2 $sqlStmt

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
