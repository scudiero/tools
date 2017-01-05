#!/bin/bash
#=======================================================================================================================
version=4.2.101 # -- dscudiero -- 01/05/2017 @ 13:39:16.62
#=======================================================================================================================
TrapSigs 'on'
Import Hello Goodbye SetSiteDirs GetCims RunCoureleafCgi
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
	#===================================================================================================================
	# Check site name syntax
	function CheckName {
		local site="$1"
		local checkStr

		[[ $(Contains ",$allowList," ",$site,") == true ]] && echo true && return 0

		for checkStr in RECOVERED bak old; do
			[[ $(Contains "$site" "$checkStr") == true ]] && echo "name contains '$checkStr'" && return 0
		done

		[[ $(Contains "$site" ' ') == true ]] && echo "name contains a blank/space" && return 0

		for checkStr in -pilot -test -dev -cim $(echo $scriptData2 | tr ',' ' '); do
			[[ $(Contains "$site" "$checkStr") == true ]] && echo true && return 0
		done

		for checkStr in '-' '_' '.' ; do
			[[ $(Contains "$site" "$checkStr") == true ]] && echo "name contains '$checkStr'" && return 0
		done

		echo true
		return 0
	}

	#===================================================================================================================
	# Retrieve the clientId from the clients table taking into accout for weirdness in client names
	#===================================================================================================================
	function GetClientId {
		local client=$1 clientId sqlStmt tempStr

		sqlStmt="select idx from $clientInfoTable where name=\"$client\" "
		RunSql2 $sqlStmt
		if [[ ${#resultSet} -ne 0 ]]; then
			clientId=${resultSet[0]}
		else
			## Hack for xxx-alaska and sites that have embedded '-' in the name
			if [[ ${site:${#site}-12} == '-alaska-test' ]]; then
				tempStr=${site:0:${#site}-5}
			elif [[ ${site:${#site}-7}  = '-alaska' ]]; then
				tempStr=$site
			else
				tempStr=$(echo $site -v | cut -d"-" -f1)
			fi
			sqlStmt="select idx from $clientInfoTable where name=\"$tempStr\" "
			RunSql2 $sqlStmt
			[[ ${#resultSet} -ne 0 ]] && clientId=${resultSet[0]} || clientId='NULL'
		fi
		echo $clientId
		return 0
	}

	#===================================================================================================================
	# Check to see if the site directory is a properly formed courseleaf site
	#===================================================================================================================
	function CheckIfDirIsCourseLeaf {
		local dir=$1

		[[ ! -d $dir/web ]] && echo false; return
		[[ $(ls $dir/web | wc -l) -le 0 ]] && echo false; return
		[[ -f $dir/web/ribbit/fsinjector.sqlite ]] && echo true && return 0

		echo false
		return 0
	}

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
insertInLine=false
fork=false
addedCalledScriptArgs="-secondaryMessagesOnly"

workerScript='insertSiteInfoTableRecord'; useLocal=true
FindExecutable "$workerScript" 'std' 'bash:sh' ## Sets variable executeFile
workerScriptFile="$executeFile"

forkCntr=0; siteCntr=0; cntr=0;
[[ $fork == true ]] && forkStr='fork' || unset forkStr

[[ $testMode == true ]] && export warehousedb='warehouseDev'

#=======================================================================================================================
# Standard arg parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello

useSiteInfoTable="${siteInfoTable}"
Msg2 "Database: $warehousedb"
Msg2 "Table: $useSiteInfoTable"

#=======================================================================================================================
# Main
#=======================================================================================================================
## Get a list of clients from the clientInfoTable, loop through the results
	sqlStmt="select name,idx from clients where recordstatus='A'"
	[[ $client != '' ]] && sqlStmt="$sqlStmt and name=\"$client\""
	sqlStmt="$sqlStmt order by name"
	RunSql2 $sqlStmt
	numClients=${#resultSet[@]}
	Msg2 "Found $numClients clients..."

## Loop through the results
	for result in ${resultSet[@]}; do
		(( cntr+=1 ))
		client=$(cut -d'|' -f1 <<< $result)
		clientId=$(cut -d'|' -f2 <<< $result)
		SetSiteDirs
		[[ $devDir == '' && $testDir == '' && $nextDir == '' && $currDir == '' && $priorDir == '' && $previewDir == '' && $publicDir == '' ]] && continue
		[[ $batchMode != true ]] && Msg2 "Processing: $client -- $clientId ($cntr/$numClients)..."
		dump -1 -n result -t client clientId devDir testDir nextDir currDir previewDir publicDir priorDir

		## Remove any existing records for this client
			sqlStmt="delete from $useSiteInfoTable where name like\"$client%\""
			RunSql2 $sqlStmt

		## Insert the record
			for env in $(tr ',' ' ' <<< "$courseleafDevEnvs $courseleafProdEnvs"); do
				[[ $env == 'pvt' ]] && continue
				eval envDir=\$${env}Dir
				[[ $envDir == '' ]] && continue
				if [[ -d $envDir/web ]]; then
					Call "$workerScriptFile" "$forkStr" "$envDir" "$clientId"
					(( forkCntr+=1 )) ; (( siteCntr+=1 ))
				fi
				if [[ $fork == true && $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
					[[ $batchMode != true ]] && Msg2 "^Waiting on forked processes, processed $forkCntr of $processedSiteCntr ...\n"
					wait
				fi
			done
			if [[ $fork == true ]]; then
				[[ $batchMode != true ]] && Msg2 "^Waiting on forked processes, processed $forkCntr of $processedSiteCntr ...\n"
				wait
			fi
	done #result in ${resultSet[@]}

## Wait for al the forked tasks to stop
	if [[ $fork == true ]]; then
		[[ $batchMode != true ]] && Msg2 "Waiting for all forked processes to complete..."
		wait
	fi

#=======================================================================================================================
## How many did we do
	Msg2
	Msg2 "Processed $siteCntr Courseleaf site directories"
	Msg2
	sqlStmt="select count(*) from $siteInfoTable where host=\"$hostName\"";
	RunSql2 "$sqlStmt"
	if [[ ${resultSet[0]} -eq 0 ]]; then
		Error "No records were inserted into in the $warehouseDb.$siteInfoTable table on host '$hostName'"
		sendMail=true
	fi
#=======================================================================================================================
## Bye-bye
#=======================================================================================================================
	if [[ $sendMail == true && $noEmails == false && $logFile != /dev/null ]]; then
		[[ $verbose == true ]] && Msg2 "\nErrors detected, sending emails...\n"
		tmpLogFile=$(mkTmpFile)
		cat $logFile | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" > $tmpLogFile
		#$DOIT mail -s "$myName detected Errors" $emailAddrs < $tmpLogFile
		$DOIT mutt -a "$tmpLogFile" -s $myName detected Errors" - $(date +"%m-%d-%Y")" -- $emailAddrs < $tmpLogFile
	fi

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
