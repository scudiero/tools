#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.3.67 # -- dscudiero -- 12/14/2016 @ 11:18:26.32
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
## Find the helper script location
workerScript='insertClientInfoRec'; useLocal=true
FindExecutable "$workerScript" 'std' 'bash:sh' ## Sets variable executeFile
workerScriptFile="$executeFile"
addedCalledScriptArgs="-secondaryMessagesOnly"

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

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
ParseArgsStd
Hello

#=======================================================================================================================
# Local Subs
#=======================================================================================================================

#=======================================================================================================================
# Main
#=======================================================================================================================
[[ $testMode == true ]] && clientInfoTable='clientsNew'

#=======================================================================================================================
## Get list of clients
#=======================================================================================================================
if [[ $client != '' ]]; then
	clients+=($client);
else
	sqlStmt="select clientcode from clients where is_active = \"Y\""
	RunSql 'sqlite' "$contactsSqliteFile" "$sqlStmt"
	[[ ${#resultSet[@]} -eq 0 ]] && Msg2 $T "No records returned from clientcode query"
	for result in "${resultSet[@]}"; do
		clients+=($result)
	done
fi

#=======================================================================================================================
## Clean out the table
#=======================================================================================================================
sql="truncate $clientInfoTable"
$DOIT RunSql 'mysql' $sql

#=======================================================================================================================
## Loop through clients
#=======================================================================================================================
clientCntr=0
numClients=${#clients[@]}
Msg2 "Found $numClients clients..."
forkCntr=1;
## Loop through the server/share directories
	for client in "${clients[@]}"; do
		(( clientCntr += 1 ))
		[[ $(Contains ",$ignoreList," ",$client,") == true ]] && Msg2 "^Skipping '$client' is in the ignore list." && continue
		unset msgPrefix
		[[ $fork == true ]] && msgPrefix='Forking off' || msgPrefix='Processing'
		Msg2 "^$msgPrefix $client ($clientCntr / ${#clients[@]})..."
		if [[ $fork == true ]]; then
			Call "$workerScriptFile" "$addedCalledScriptArgs" &
			rc=$?
			(( forkCntr+=1 ))
			## Wait for forked process to finish, only run maxForkedProcesses at a time
			if [[ $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
				#[[ $batchMode != true ]] &&
				Msg2 "^Waiting on forked processes, processed $forkCntr of $processedSiteCntr ...\n"
				wait
			fi
			[[ $fork != true && $(($clientCntr % processNotify)) -eq 0 ]] && Msg2 "\n^*** Processed $clientCntr out of $numClients\n"
		else
			Call "$workerScriptFile" "$addedCalledScriptArgs" ; rc=$?
		fi
	done

## Wait for all the forked tasks to stop
	if [[ $fork == true ]]; then
		[[ $batchMode != true ]] && Msg2 "^Waiting for all forked processes to complete..."
		wait
	fi

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
