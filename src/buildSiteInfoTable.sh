#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
version="4.4.12" # -- dscudiero -- Mon 12/17/2018 @ 07:50:02
#=======================================================================================================================
TrapSigs 'on'
myIncludes="SetSiteDirs SetFileExpansion RunSql StringFunctions ProtectedCall FindExecutable PushPop"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Sync the data warehouse '$siteInfoTable' table with the transactional data from the contacts db data and the live site data"

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
	function buildSiteInfoTable-ParseArgsStd {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		quick=false
		myArgs+=("quick|quick|switch|quick||script|Do quickly, skip processing the admins information")
		myArgs+=("table|tableName|option|tableName||script|The name of the database table to load")
	}
	function buildSiteInfoTable-Goodbye  { # or Goodbye-$myName
		SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
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
	workerScript='insertSiteInfoTableRecord'
	workerScriptFile="$(FindExecutable "$workerScript")"
	[[ -z $workerScriptFile ]] && Terminate "Could find the workerScriptFile file ('$workerScript')"

forkCntr=0; siteCntr=0; clientCntr=0;
[[ $testMode == true ]] && export warehousedb="$warehouseDev"

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
Hello
Info "Loading script defaults..."
GetDefaultsData $myName
Info "Parsing arguments..."
ParseArgsStd $originalArgStr
if [[ $batchMode != true ]]; then
	verifyMsg="You are asking to re-generate the data warehouse '$siteInfoTable' and "$siteAdminsTable" table"
	[[ -n $client ]] && verifyMsg="$verifyMsg record(s) for client '$client'"
	VerifyContinue "$verifyMsg"
fi

[[ -n $env ]] && envList="$env" || envList="$courseleafDevEnvs,$courseleafProdEnvs"
[[ $fork == true ]] && forkStr='-fork' || unset forkStr

## Which table to use
	useSiteInfoTable="$siteInfoTable"
	useSiteAdminsTable="$siteAdminsTable"
	sqlStmt="select count(*) FROM information_schema.TABLES WHERE (TABLE_SCHEMA=\"$warehouseDb\") AND (TABLE_NAME=\"$useSiteInfoTable\")"
	RunSql $sqlStmt
	[[ ${resultSet[0]} -ne 1 ]] && Terminate "Could not locate the load table '$useSiteInfoTable'"
	Msg "Loading tables: $useSiteInfoTable, $useSiteAdminsTable"

#=======================================================================================================================
# Main
#=======================================================================================================================
## loop through the clients
	declare -A dbClients
	unset clientDirs

	## Get clients from the clients transactional table, build a hash table with the client key for each client
		declare -A dbClients
		sqlStmt="select clientcode,clientkey from clients where is_active = \"Y\""
		[[ $client != '' ]] && sqlStmt="$sqlStmt and clientcode=\"$client\"";
		dump -1 sqlStmt
		RunSql "$contactsSqliteFile" "$sqlStmt"
		[[ ${#resultSet[@]} -eq 0 ]] && Terminate "No records returned from clientcode query from:\n^$contactsSqliteFile\n^$sqlStmt"
		for result in ${resultSet[@]}; do
			dbClients["${result%%|*}"]="${result##*|}"
		done

	## Get the list of actual directories pulling only those in a production server share
		dump -1 prodServers
		SetFileExpansion 'on'
		if [[ -z $client ]]; then
			clientDirs+=($(find /mnt/* -maxdepth 1 -mindepth 1 2> /dev/null | sort | grep "${prodServers//,/\|}"))
		else
			clientDirs+=($(find /mnt/* -maxdepth 1 -mindepth 1 2> /dev/null | grep "${prodServers//,/\|}" | grep $client || true))
		fi
		SetFileExpansion
		numClients=${#clientDirs[@]}

	if [[ $verboseLevel -ge 1 ]]; then
		echo
		Msg "dbClients:"; for i in "${!dbClients[@]}"; do printf "\t[$i] = >${dbClients[$i]}<\n"; done; echo
		Msg "clientDirs:"; for i in "${!clientDirs[@]}"; do printf "\t[$i] = >${clientDirs[$i]}<\n"; done; echo
	fi
	## Loop through actual clientDirs
		declare -A foundCodes ## Has table to keep track of 'seen' client codes (because we can have xxx and xxx-test)
		for clientDir in ${clientDirs[@]}; do
dump -n clientDir
			clientCode="$(basename $clientDir)"; clientCode="${clientCode//-test/}"
dump -t clientCode
			foundCodes["$clientCode"]=true
			if [[ ${dbClients[$clientCode]+abc} ]]; then
				(( clientCntr+=1 ))
				client="$clientCode"
				clientId=${dbClients[$client]}
dump -t -t client clientId
				[[ $batchMode != true ]] && Msg "Processing: $client (Id: $clientId) ($clientCntr/$numClients)..."
				## Get the envDirs, make sure we have some
				for env in ${envList//,/ }; do unset ${env}Dir ; done
verboseLevel=3
				SetSiteDirs
verboseLevel=1
				## Loop through the environments, processing any that are not null
				for env in ${envList//,/ }; do
					[[ $env == 'pvt' ]] && continue
					token="${env}Dir" ; envDir="${!token}"
Dump -t -t -t env -t envDir
					[[ -z $envDir || ! -d $envDir ]] && continue
					[[ ${foundCodes[${clientCode}.${env}]+abc} ]] && continue  ## have we seen this client code before, if yes then skip
					Verbose 1 2 "Processing env: $env"
					$DOIT source "$workerScriptFile" "$envDir" "$clientId" "$forkStr -tableName $useSiteInfoTable"
					(( forkCntr+=1 )) ; (( siteCntr+=1 ))
					foundCodes["${clientCode}.${env}"]=true
					if [[ $fork == true && $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
						[[ $batchMode != true ]] && Msg "^Waiting on forked processes..."
						wait
					fi
				done
				[[ $fork == true && $batchMode != true ]] && Msg "^Waiting on forked processes (final)..." && wait
			fi #[[ ${dbClients[$(basename $clientDir)]+abc} ]]
		done #clientDir in ${clientDirs[@]}

## Wait for all the forked tasks to stop
	if [[ $fork == true ]]; then
		[[ $batchMode != true ]] && Msg "Waiting for all forked processes to complete..."
		wait
	fi

## Processing summary
	Msg
	Msg "Processed $siteCntr Courseleaf site directories"
	Msg
	sqlStmt="select count(*) from $useSiteInfoTable where host=\"$hostName\"";
	RunSql "$sqlStmt"
	if [[ ${resultSet[0]} -eq 0 ]]; then
		Error "No records were inserted into in the ${warehouseDb}.${useSiteInfoTable} table on host '$hostName'"
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
## Thu Jan  5 13:40:29 CST 2017 - dscudiero - switch to RunSql
## Thu Jan  5 14:59:40 CST 2017 - dscudiero - Switch to use RunSql
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
## Fri Feb 10 16:02:08 CST 2017 - dscudiero - Tweak client support to add $ to the grep to only pickup the base client dir
## Tue Feb 14 07:28:32 CST 2017 - dscudiero - remove Pause statement
## Tue Feb 14 13:19:07 CST 2017 - dscudiero - Refactored to delete the client records before inserting a new one
## 04-06-2017 @ 10.09.20 - (4.3.28)    - dscudiero - renamed RunCourseLeafCgi, use new name
## 04-17-2017 @ 12.31.07 - (4.3.33)    - dscudiero - run clientDirs in a ProtectedCall
## 07-31-2017 @ 07.25.07 - (4.3.33)    - dscudiero - add imports
## 09-06-2017 @ 07.14.46 - (4.3.34)    - dscudiero - Tweak error messaging
## 09-07-2017 @ 07.40.55 - (4.3.35)    - dscudiero - Fix problem where the passed tableName was being picked up as a client name
## 09-27-2017 @ 16.50.50 - (4.3.67)    - dscudiero - Refasctored messaging
## 09-28-2017 @ 06.52.04 - (4.3.68)    - dscudiero - Remove debug statements
## 09-29-2017 @ 10.14.44 - (4.3.69)    - dscudiero - Update FindExcecutable call for new syntax
## 10-18-2017 @ 13.56.37 - (4.3.70)    - dscudiero - Add debug statements
## 10-20-2017 @ 13.11.25 - (4.3.79)    - dscudiero - Fix problem with a missing fi
## 10-23-2017 @ 07.30.44 - (4.3.80)    - dscudiero - Tweak messaging
## 10-25-2017 @ 08.40.03 - (4.3.81)    - dscudiero - Cosmetic/minor change
## 10-30-2017 @ 08.50.42 - (4.3.84)    - dscudiero - Filter out '-test' from the clientDirs
## 10-31-2017 @ 08.51.21 - (4.3.85)    - dscudiero - Wrap the grep calls in a ProtectedCall
## 11-01-2017 @ 15.24.36 - (4.3.98)    - dscudiero - Updated client directory selection to use only server directories in the prodServer or devServers lists
## 11-01-2017 @ 15.50.25 - (4.3.99)    - dscudiero - Switch to use ParseArgsStd
## 12-01-2017 @ 10.24.36 - (4.3.105)   - dscudiero - Fix problem when the client does not have a next site
## 12-20-2017 @ 06.55.52 - (4.3.119)   - dscudiero - Remove the 'set' option onthe SetSiteDirs call
## 03-22-2018 @ 14:05:51 - 4.3.124 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:31:44 - 4.3.125 - dscudiero - D
## 03-26-2018 @ 12:51:29 - 4.3.127 - dscudiero - Misc cleanup
## 04-12-2018 @ 12:18:40 - 4.3.128 - dscudiero - Remove debug
## 09-05-2018 @ 15:54:24 - 4.4.4 - dscudiero - Tweak messaging
## 10-23-2018 @ 12:36:53 - 4.4.5 - dscudiero - Cosmetic/minor change/Sync
## 12-12-2018 @ 07:32:38 - 4.4.6 - dscudiero - Add dump of prodServers
## 12-12-2018 @ 12:16:46 - 4.4.7 - dscudiero - Added debug stuff
## 12-14-2018 @ 11:59:07 - 4.4.11 - dscudiero - Add debug
## 12-17-2018 @ 07:50:22 - 4.4.12 - dscudiero - Add debug statements
