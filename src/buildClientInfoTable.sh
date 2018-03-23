#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.4.44 # -- dscudiero -- Fri 03/23/2018 @ 14:26:19.22
#=======================================================================================================================
TrapSigs 'on'

myIncludes="Msg RunSql FindExecutable StringFunctions PushPop"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Sync the data warehouse '$clientInfoTable' table with the transactional data from the contacts db data"

#=======================================================================================================================
# Synchronize client data from the transactional sqlite db and the data warehouse
#=======================================================================================================================
#=======================================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#=======================================================================================================================

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
function buildClientInfoTable-ParseArgsStd  { # or parseArgs-local
	myArgs+=("inpl|inplace|switch|inPlace||script|Load the main clients table in place")
	return 0
}

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
fork=false
processNotify=30
forkCntr=0; cntr=0;
addedCalledScriptArgs="-secondaryMessagesOnly"

## Find the helper script location
	workerScript='insertClientInfoRec'
	workerScriptFile="$(FindExecutable $workerScript -sh)"
	[[ -z $workerScriptFile ]] && Terminate "Could find the workerScriptFile file ('$workerScript')"

## Local variable initialization
	GetDefaultsData $myName
	unset tokens ignoreShares ignoreSites
	if [[ -n $ignoreList ]]; then
		tokens+=("$(cut -d' ' -f1 <<< $ignoreList)")
		#tokens+=("$(cut -d' ' -f2 <<< $ignoreList)")
		for token in "${tokens[@]}"; do
			tokenVar=$(cut -d ':' -f1 <<< $token)
			tokenVal=$(cut -d ':' -f2- <<< $token)
			eval $tokenVar="$tokenVal"
		done
	fi

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
Hello
ParseArgsStd $originalArgStr
[[ $batchMode != true ]] && VerifyContinue "You are asking to re-generate the data warehouse '$clientInfoTable' table"

#=======================================================================================================================
# Local Subs
#=======================================================================================================================

#=======================================================================================================================
# Main
#=======================================================================================================================
[[ $fork == true ]] && forkStr='&' || unset forkStr
[[ $testMode == true ]] && export warehousedb='warehouseDev'

## Get list of clients from the transactional system
	if [[ -n $client ]]; then
		clients+=($client);
		useClientInfoTable="$clientInfoTable"
		inPlace=true
	else
		[[ $inPlace == true ]] && useClientInfoTable="$clientInfoTable" || useClientInfoTable="${clientInfoTable}New"
		sqlStmt="select clientcode from clients where is_active = \"Y\" order by clientcode"
		RunSql "$contactsSqliteFile" "$sqlStmt"
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "No records returned from clientcode query from '$contactsSqliteFile'"
		for result in "${resultSet[@]}"; do
			clients+=($result)
		done
	fi
	numClients=${#clients[@]}
	Msg "Found $numClients clients in transactional 'clients' table..."
	Msg "Database: $warehouseDb"
	Msg "Table: $useClientInfoTable"

## Table management
	if [[ $inPlace != true && -z $client ]]; then
		## Create a temporary copy of the clients table, load new data to that table
		[[ $batchMode != true ]] && Msg "^Creating work table '$useClientInfoTable'..."
		sqlStmt="drop table if exists ${clientInfoTable}Bak"
		RunSql $sqlStmt
		if [[ $useClientInfoTable != $clientInfoTable ]]; then
			sqlStmt="drop table if exists $useClientInfoTable"
			RunSql $sqlStmt
			sqlStmt="create table $useClientInfoTable like $clientInfoTable"
			RunSql $sqlStmt
		else 
			sqlStmt="truncate $useClientInfoTable"
			RunSql $sqlStmt
		fi
	fi

## Loop through clients
	clientCntr=0
	forkCntr=1;
	for client in "${clients[@]}"; do
		(( clientCntr += 1 ))
		if [[ $(Contains ",$ignoreList," ",$client,") == true ]]; then
			[[ $batchMode != true ]] && Msg "^Skipping '$client' is in the ignore list."
			continue
		fi
		unset msgPrefix
		[[ $fork == true ]] && msgPrefix='Forking off' || msgPrefix='Processing'
		[[ $batchMode != true ]] && Msg "^$msgPrefix $client ($clientCntr / ${#clients[@]})..."
		source "$workerScriptFile" "$addedCalledScriptArgs"  "$forkStr"
		rc=$?
		(( forkCntr+=1 ))
		## Wait for forked process to finish, only run maxForkedProcesses at a time
		if [[ $fork == true && $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
			[[ $batchMode != true ]] && Msg "^Waiting on forked processes...\n"
			wait
		fi
		[[ $fork != true && $(($clientCntr % processNotify)) -eq 0 ]] && Msg "\n^*** Processed $clientCntr out of $numClients\n"
	done

## Wait for all the forked tasks to stop
	if [[ $fork == true ]]; then
		[[ $batchMode != true ]] && Msg "^Waiting for all forked processes to complete..."
		wait
	fi

## Swap client tables
	if [[ $inPlace != true ]]; then
		[[ $batchMode != true ]] && Msg "^Swapping databases ..."
		sqlStmt="select count(*) from ${clientInfoTable}New"
		RunSql $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "New clients table has zero rows, keeping original"

		sqlStmt="select count(*) from ${clientInfoTable}New"
		RunSql $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			[[ $batchMode != true ]] && Msg "^^$clientInfoTable --> ${clientInfoTable}Bak"
			sqlStmt="rename table $clientInfoTable to ${clientInfoTable}Bak"
			RunSql $sqlStmt
		fi

		[[ $batchMode != true ]] && Msg "^^${clientInfoTable}New --> $clientInfoTable"
		sqlStmt="rename table ${clientInfoTable}New to $clientInfoTable"
		RunSql $sqlStmt
	fi

	Msg "\nInserted $clientCntr records into $clientInfoTable"

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
## Thu Jan  5 12:37:46 CST 2017 - dscudiero - re-factored to create a new table, insert data and then rename if successful
## Thu Jan  5 12:53:22 CST 2017 - dscudiero - remove debug statements
## Thu Jan  5 12:56:56 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 13:40:11 CST 2017 - dscudiero - removed debug code
## Thu Jan  5 14:00:07 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan  6 07:26:18 CST 2017 - dscudiero - Fix syntax error
## Fri Jan  6 07:41:30 CST 2017 - dscudiero - Add Messages for the swap db process
## Mon Jan  9 13:29:00 CST 2017 - dscudiero - Add an inplace option to just update the clients table directly
## Tue Jan 10 12:54:37 CST 2017 - dscudiero - Added 'inPlace' option
## Wed Jan 11 07:00:04 CST 2017 - dscudiero - Add status at the end of processing
## Tue Jan 17 08:58:27 CST 2017 - dscudiero - x
## Tue Jan 17 09:36:47 CST 2017 - dscudiero - Fix issues with swapping databases
## Thu Jan 19 07:13:53 CST 2017 - dscudiero - Fixed erronious messaging
## Fri Jan 20 07:17:42 CST 2017 - dscudiero - General syncing of dev to prod
## Mon Jan 23 11:26:38 CST 2017 - dscudiero - Fix sql query checking the clients table count
## Tue Feb 14 13:18:42 CST 2017 - dscudiero - Refactored to delete the client records before inserting a new one
## 04-17-2017 @ 12.30.14 - (2.3.112)   - dscudiero - modify logic for what database to use if a client was passed in
## 05-03-2017 @ 11.41.51 - (2.3.113)   - dscudiero - Order the client list by name
## 06-13-2017 @ 14.03.50 - (2.3.114)   - dscudiero - Change to use -n and -z notation
## 09-29-2017 @ 10.14.32 - (2.3.122)   - dscudiero - Update FindExcecutable call for new syntax
## 10-20-2017 @ 08.58.06 - (2.3.123)   - dscudiero - Replace Call by source
## 10-24-2017 @ 07.28.11 - (2.3.124)   - dscudiero - Added PushPop to the import list
## 10-24-2017 @ 07.30.01 - (2.3.125)   - dscudiero - Cosmetic/minor change
## 10-24-2017 @ 07.42.43 - (2.4.0)     - dscudiero - set version
## 10-27-2017 @ 07.52.38 - (2.4.1)     - dscudiero - Add debug statements
## 10-27-2017 @ 13.35.11 - (2.4.33)    - dscudiero - Cosmetic/minor change
## 10-30-2017 @ 08.29.24 - (2.4.37)    - dscudiero - if the target table == source table then do not drop the table
## 10-31-2017 @ 11.20.47 - (2.4.39)    - dscudiero - Fix reported inserted client records
## 11-01-2017 @ 15.50.16 - (2.4.42)    - dscudiero - Switch to use ParseArgsStd
## 03-22-2018 @ 14:05:34 - 2.4.43 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:31:28 - 2.4.44 - dscudiero - D
