#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
version=4.3.25 # -- dscudiero -- 02/10/2017 @ 15:49:53.34
#=======================================================================================================================
TrapSigs 'on'

imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports SetSiteDirs GetCims RunCoureleafCgi"
Import "$imports"
originalArgStr="$*"
scriptDescription="Scratch build the warhouse 'sites' table"

#=======================================================================================================================
# Run nightly from cron
# 	Script to update site_info database with all sites and their versions
#=======================================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 08-30-13 -- 	dgs - Initial coding
# 05-06-14	--	dgs	-Deal with old cims that are in '/cim/' not 'xxxxadmin' (see UA)
# 05-20-14	--	dgs	-Added test env and added site url
# 07-08-15 --	dgs -Do not write a record if a client record was not found
# 07-17-15 --	dgs - Migrated to framework 5
#=======================================================================================================================

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
	function parseArgs-buildSiteInfoTable {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		noNameCheck=false
		quick=false
		argList+=(-noNameCheck,3,switch,noNameCheck,,script,"Do not check site names for syntax - only valid with -x and when a site name is specified")
		argList+=(-quick,3,switch,quick,,script,"Do Quickly, skip processing the admins information")
		argList+=(-tableName,5,option,tableName,,script,"The name of the 'sites' table to load")
	}
	function Goodbye-buildSiteInfoTable  { # or Goodbye-$myName
		SetFileExpansion 'on'
		rm -rf $tmpRoot > /dev/null 2>&1
		SetFileExpansion
		return 0
	}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
insertInLine=false
fork=false
addedCalledScriptArgs="-secondaryMessagesOnly"

## Find the location of the worker script, speeds up subsequent calls
	workerScript='insertSiteInfoTableRecord'; useLocal=true
	FindExecutable "$workerScript" 'std' 'bash:sh' ## Sets variable executeFile
	workerScriptFile="$executeFile"

forkCntr=0; siteCntr=0; clientCntr=0;
[[ $testMode == true ]] && export warehousedb="$warehouseDev"

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
[[ -n $env ]] && envList="$env" || envList="$courseleafDevEnvs $courseleafProdEnvs"
[[ $fork == true ]] && forkStr='fork' || unset forkStr

## Which table to use
	useSiteInfoTable="$siteInfoTable"
	useSiteAdminsTable="$siteAdminsTable"
	if [[ -n $tableName ]]; then
		useSiteInfoTable="$tableName"
		let tmpLen=${#tableName}-3
		[[ ${tableName:$tmpLen:3} == 'New' ]] && useSiteAdminsTable="${siteAdminsTable}New"
	fi
	sqlStmt="select count(*) FROM information_schema.TABLES WHERE (TABLE_SCHEMA=\"$warehouseDb\") AND (TABLE_NAME=\"$useSiteInfoTable\")"
	RunSql2 $sqlStmt
	[[ ${resultSet[0]} -ne 1 ]] && Terminate "Could not locate the load table '$useSiteInfoTable'"


Msg2 "Loading tables: $useSiteInfoTable, $useSiteAdminsTable"

#=======================================================================================================================
# Main
#=======================================================================================================================
## loop through the clients
	declare -A dbClients
	unset clientDirs
	## Get clients from the clientinfotable, build a hash table with the clientInfoTable key for each client
	sqlStmt="select name,idx from clients where recordstatus='A'"
	[[ $client != '' ]] && sqlStmt="$sqlStmt and name=\"$client\""
	sqlStmt="$sqlStmt order by name"
	RunSql2 $sqlStmt
	numClients=${#resultSet[@]}
	[[ $numClients -eq 0 ]] && Terminate "Could not retrieve any client records from '$warehouseDb.$clientInfoTable'"
	Msg2 "Found $numClients clients..."
	for result in ${resultSet[@]}; do
		dbClients["${result%%|*}"]="${result##*|}"
	done
	## Get the list of actual clients on this server
	if [[ -z $client ]]; then
		clientDirs=($(find /mnt -maxdepth 2 -mindepth 1 -type d 2> /dev/null | grep -v '^/mnt/dev'))
	else
		clientDirs+=($(find /mnt/* -maxdepth 1 -mindepth 1 2> /dev/null | grep $client))
	fi
	if [[ $verboseLevel -ge 1 ]]; then
		echo
		Msg2 "dbClients:"; for i in "${!dbClients[@]}"; do printf "\t\t[$i] = >${dbClients[$i]}<\n"; done; echo
		Msg2 "clientDirs:"; for i in "${!clientDirs[@]}"; do printf "\t\t[$i] = >${clientDirs[$i]}<\n"; done; echo
	fi
Pause

	## Loop through actual clientDirs
	for clientDir in ${clientDirs[@]}; do
		if [[ ${dbClients[$(basename $clientDir)]+abc} ]]; then
			(( clientCntr+=1 ))
			client="$(basename $clientDir)"
			clientId=${dbClients[$client]}
			## Get directories, if none found then skip this directory
			unset devDir testDir nextDir currDir priorDir previewDir publicDir
			SetSiteDirs
			[[ -z ${devDir}${testDir}${nextDir}${currDir}${priorDir}${previewDir}${publicDir} ]] && continue

			[[ $batchMode != true ]] && Msg2 "Processing: $client -- $clientId (~$clientCntr/$numClients)..."
			## Remove any existing records for this client/env
			[[ -n $env ]] && andClause="and env=\"$env\"" || unset andClause
			sqlStmt="delete from $useSiteInfoTable where name like\"$client%\" $andClause"
			RunSql2 $sqlStmt
			## Loop through envs and process the site env directory
			for env in $(tr ',' ' ' <<< "$envList"); do
				[[ $env == 'pvt' ]] && continue
				eval envDir=\$${env}Dir
				[[ -z $envDir ]] && continue
				if [[ -d $envDir/web ]]; then
					Call "$workerScriptFile" "$forkStr" "$envDir" "$clientId" "-tableName $useSiteInfoTable"
					(( forkCntr+=1 )) ; (( siteCntr+=1 ))
				fi
				if [[ $fork == true && $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
					[[ $batchMode != true ]] && Msg2 "^Waiting on forked processes...\n"
					wait
				fi
			done
			if [[ $fork == true ]]; then
				[[ $batchMode != true ]] && Msg2 "^Waiting on forked processes...\n"
				wait
			fi
		fi #[[ ${dbClients[$(basename $clientDir)]+abc} ]]
	done #clientDir in ${clientDirs[@]}

## Wait for all the forked tasks to stop
	if [[ $fork == true ]]; then
		[[ $batchMode != true ]] && Msg2 "Waiting for all forked processes to complete..."
		wait
	fi

## Processing summary
	Msg2
	Msg2 "Processed $siteCntr Courseleaf site directories"
	Msg2
	sqlStmt="select count(*) from $useSiteInfoTable where host=\"$hostName\"";
	RunSql2 "$sqlStmt"
	if [[ ${resultSet[0]} -eq 0 ]]; then
		Error "No records were inserted into in the $warehouseDb.$useSiteInfoTable table on host '$hostName'"
		sendMail=true
	fi

#=======================================================================================================================
## Bye-bye
#=======================================================================================================================
Goodbye 0 'alert'

#=======================================================================================================================
# Check in log
#=======================================================================================================================
# 10-16-2015 -- dscudiero -- Move to framework 6 (2.7)
# 10-21-2015 -- dscudiero -- Updated for Framework 6 (3.2)
# 10-23-2015 -- dscudiero -- Fix logic with assigning site urls (3.3)
# 10-23-2015 -- dscudiero -- fixed issue collecting the cims data (3.4)
## Fri Mar 18 12:45:58 CDT 2016 - dscudiero - Added gathering of the site admins from the courseleaf.cfg file
## Fri Mar 18 14:23:25 CDT 2016 - dscudiero - Add -quick option
## Mon Mar 21 06:59:15 CDT 2016 - dscudiero - remove early debug stuff
## Mon Mar 21 13:03:45 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Mar 23 11:47:30 CDT 2016 - dscudiero - Refactored to fork off work to inserSiteInfoTableRecord script
## Fri Mar 25 07:27:44 CDT 2016 - dscudiero - Add nofork option
## Fri Mar 25 08:27:52 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 25 09:58:30 CDT 2016 - dscudiero - Fix problem with noFork
## Fri Mar 25 15:08:16 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Mar 25 15:16:03 CDT 2016 - dscudiero - Fix setting of verbose level on addedCalledScriptArgs
## Mon Mar 28 08:04:19 CDT 2016 - dscudiero - switch -noFork to -fork
## Mon Mar 28 09:07:22 CDT 2016 - dscudiero - Set default value for fork
## Mon Mar 28 10:01:07 CDT 2016 - dscudiero - Only wait on tasks if -fork is avtive
## Tue Mar 29 09:32:07 CDT 2016 - dscudiero - Add DOIT flag on insertSiteInfoTableRecord calls
## Tue Mar 29 12:22:22 CDT 2016 - dscudiero - Removed debug statements
## Tue Apr  5 13:49:38 CDT 2016 - dscudiero - Completely re-written to allow for parallel exection
## Wed Apr  6 11:26:29 CDT 2016 - dscudiero - Fixed processing on downlevel shells and refactored to pull all site directories before processing
## Wed Apr  6 12:52:36 CDT 2016 - dscudiero - Switch cims processing to use the cimStr from GetCims
## Wed Apr  6 13:03:22 CDT 2016 - dscudiero - updated waiting for process message to show status
## Wed Apr  6 16:08:30 CDT 2016 - dscudiero - switch for
## Thu Apr  7 07:33:11 CDT 2016 - dscudiero - Pull setting of maxForkedProcess as it is now done in the framework
## Thu Apr  7 07:45:50 CDT 2016 - dscudiero - remove tmp files in cleanup
## Wed Apr 27 16:21:04 CDT 2016 - dscudiero - Switch to use RunSql
## Wed May 18 06:55:45 CDT 2016 - dscudiero - Added clean out of siteAdmins table, switch to Msg2
## Thu Jul  7 12:06:39 CDT 2016 - dscudiero - Wrap cp to share dir with a ProctedCall
## Tue Aug  9 07:20:04 CDT 2016 - dscudiero - Fix problem where table is truncated if a single client is specified
## Mon Aug 22 08:59:10 CDT 2016 - dscudiero - Switch to use mutt for email
## Tue Oct 11 07:59:27 CDT 2016 - dscudiero - Tweak messaging
## Thu Dec 29 14:03:14 CST 2016 - dscudiero - switch to use RunMySql
## Thu Jan  5 13:40:29 CST 2017 - dscudiero - switch to RunSql2
## Thu Jan  5 14:59:40 CST 2017 - dscudiero - Switch to use RunSql2
## Thu Jan  5 15:50:37 CST 2017 - dscudiero - Strip non-ascii chars from reportsVer, remove debug statements
## Fri Jan  6 08:04:17 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan  6 08:12:36 CST 2017 - dscudiero - Fix problem where not processing all envs for clients > 1
## Fri Jan  6 10:10:29 CST 2017 - dscudiero - Do not unset env variable after argument parsing
## Fri Jan  6 15:57:49 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 11 09:46:21 CST 2017 - dscudiero - updated code comments
## Wed Jan 18 07:20:19 CST 2017 - dscudiero - Add -table argument
## Tue Jan 24 07:35:08 CST 2017 - dscudiero - Add debug
## Wed Jan 25 08:24:40 CST 2017 - dscudiero - refactor how we set useSitesTable & useSiteAdminsTable
## Thu Jan 26 06:56:00 CST 2017 - dscudiero - Fix problem setting tableName
## Thu Jan 26 07:31:31 CST 2017 - dscudiero - Add a check to make sure the target table exists
## Thu Jan 26 07:50:16 CST 2017 - dscudiero - Tweak messaging
## Fri Jan 27 08:04:43 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Feb  7 08:34:51 CST 2017 - dscudiero - Fix bug checking if the passed table name exists
## Wed Feb  8 10:57:22 CST 2017 - dscudiero - v
## Fri Feb 10 15:59:40 CST 2017 - dscudiero - Add ability to specify a client name
