#!/bin/bash
version=4.2.65 # -- dscudiero -- 11/28/2016 @ 15:48:21.83
originalArgStr="$*"
scriptDescription="Scratch build the warhouse 'sites' table"
TrapSigs 'on'

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
		argList+=(-share,5,option,singleShare,,script,"Process on this 'server share'")
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
		RunSql 'mysql' $sqlStmt
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
			RunSql 'mysql' $sqlStmt
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
unset singleClient singleShare
fork=false

workerScript='insertSiteInfoTableRecord'; useLocal=true
FindExecutable "$workerScript" 'std' 'bash:sh' ## Sets variable executeFile
workerScriptFile="$executeFile"

GetDefaultsData $myName
unset tokens ignoreShares ignoreSites
if [[ $ignoreList != '' ]]; then
	tokens+=("$(cut -d' ' -f1 <<< $ignoreList)")
	tokens+=("$(cut -d' ' -f2 <<< $ignoreList)")
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

[[ $client != '' ]] && singleClient=$client
if [[ $noNameCheck == true ]]; then
	if [[ $client == '' ]]; then Msg2 $T "The 'noNameCheck' flag can only be specified with a client name"; fi
	DOIT='echo'
fi
## If running a down level version of the shell, then force processing to be inline with the script
if [[ ${BASH_VERSION:0:1} -lt 4 ]]; then
	insertInLine=true
	fork=false
else
	declare -A siteDirs
fi

## Set arguments to called scripts
addedCalledScriptArgs="-secondaryMessagesOnly"
Hello

unset verifyArgs
[[ $singleClient != '' ]] && verifyArgs+=("Client:$singleClient")
[[ $singleShare != '' ]] && verifyArgs+=("Share:$singleShare")
verifyArgs+=("noNameCheck:$noNameCheck")
verifyArgs+=("quick:$quick")
verifyArgs+=("fork:$fork")
[[ $fork == true ]] && verifyArgs+=("Number of forked processes:$maxForkedProcesses")
VerifyContinue "You are asking to build the '$siteInfoTable' table"

#=======================================================================================================================
# Main
#=======================================================================================================================
## Get the list of server/share directories
	unset shareDirs
	if [[ $singleShare != '' ]]; then
		shares+=($(echo $singleShare | tr ',' ' '))
	else
		find /mnt -maxdepth 1 -mindepth 1 -type d -printf "%f\n" | sort > $tmpFile
		unset shares; ifs="$IFS"; IFS=$'\n'; while read line; do shares+=($line); done < $tmpFile; IFS="$ifs"
	fi
	[[ $testMode == true ]] && unset shares && shares+=(arches) && shares+=(dev11)
	#for share in "${shares[@]}"; do echo 'share = >'$share'<'; done; QUIT

## Clean out the database tables table
	sqlStmt="delete from $siteInfoTable where host=\"$hostName\""
	[[ $singleClient != '' ]] && sqlStmt="$sqlStmt and name=\"$singleClient\""
	RunSql 'mysql' $sqlStmt

	sqlStmt="delete from $siteAdminsTable where host=\"$hostName\""
	[[ $singleClient != '' ]] && sqlStmt="$sqlStmt and name=\"$singleClient\""
	RunSql 'mysql' $sqlStmt

forkCntr=1;
unset keyArray rawShareCntr processedShareCntr rawSiteCntr processedSiteCntr
## Loop through the server/share directories
	Msg2 "Processing server shares (inLine: $insertInLine)..."
	for share in ${shares[@]}; do
		(( rawShareCntr+=1 ))
		[[ $(Contains ",$ignoreShares," ",$share,") == true ]] && Msg2 $V1 "^'$share' -- is on the ignoreList, skipping" && continue  ## Skip ignorelist
		#[[ ${share:0:3} == 'dev' ]] && continue  ## Skip dev directories

		MsgNONL "^$share"

		shareType='prod'; suffix='/'; unset env
		[[ ${share:0:3} == 'dev' ]] && shareType='dev' && env='dev' && suffix='/web/'
		shareDir="/mnt/$share$suffix"

		## Can we access the share  directory
		cd "$shareDir" 2> /dev/null || true
		[[ $(pwd) != "$shareDir" && "$(pwd)/" != "$shareDir" ]] && Msg2 $V1 "^^'$share' -- Could not cd to '$shareDir', skipping" && sendMail=true && continue
		topLevel=$(pwd)

		(( processedShareCntr+=1 ))
		## Get the list of site directories
		find $shareDir -maxdepth 1 -type d -printf "%f\n" | sort > $tmpFile
		unset sites; ifs="$IFS"; IFS=$'\n'; while read line; do sites+=($line); done < $tmpFile; IFS="$ifs"
		Msg2 " (${#sites[@]})"

		## Loop through the sites
		for site in "${sites[@]}"; do
			[[ $singleClient != '' && $site != $singleClient ]] && continue
			[[ $site == "$share/" ]] && continue
			(( rawSiteCntr+=1 ))
			[[ $(Contains ",$ignoreSites," ",$site,") == true ]] && Msg2 $V1 "^^^'$site' -- is on the ignoreList, skipping" && continue
			if [[ $noNameCheck != true ]]; then
				tempStr="$(CheckName "$site")"
				[[ $tempStr != true ]] && Msg2 $V1 "^^'$site' -- Failed name check, $tempStr (site:$site, type:$shareType, env:$env)" && continue
			fi
			client=$site
			[[ $singleClient != '' && $client != $singleClient ]] && continue

			## Process dir
			[[ ${site:${#site}-4:4} == '-dev' ]] && client=${site:0:${#site}-4} && env='dev'
			[[ ${site:${#site}-5:5} == '-test' ]] && client=${site:0:${#site}-5} && env='test'
			clientId=$(GetClientId "$client")
			[[ $clientId == 'NULL' ]] && Msg2 $V1 "^^'$site' -- Failed clientId lookup" && continue
			## Make sure we can access the directory
			ProtectedCall "cd ${shareDir}${site} > /dev/null 2>&1"
			[[ $(pwd) != "${shareDir}${site}" ]] && Msg2 $V1 "^^^'site' -- Could not cd to '${shareDir}${site}', skipping" && sendMail=true && continue
			siteDir="${shareDir}${site}"
			## Insert a record into the siteInfoTable
			if [[ $shareType = 'dev' ]]; then
				[[ $(CheckIfDirIsCourseLeaf "$siteDir") == false ]] && Msg2 $V1 "^^^'$site' -- '$siteDir' is not a courseleaf site, skipping" && continue
				(( processedSiteCntr+=1 ))
				if [[ $insertInLine == true ]]; then
					Msg2 "^^$share/$site"
					Call "$workerScriptFile" "$siteDir" -clientId $clientId -secondaryMessagesOnly; rc=$?
				else
					siteDirs["$siteDir"]="$clientId"
					keyArray+=("$siteDir")
				fi
			else
				## Public site so loop through the environments
				SetFileExpansion 'on'
				for dir in */; do
					dir=${dir:0:${#dir}-1}
					unset env
					for testEnv in $(echo $prodEnvs | tr ',' ' '); do
						[[ $dir == $testEnv ]] && env=$dir && break
					done
					if [[ $env != '' ]]; then
						siteDir="${shareDir}${site}/$env"
						[[ $(CheckIfDirIsCourseLeaf "$siteDir") == false ]] && Msg2 $V1 "^^^'$site' -- '$siteDir' is not a courseleaf site, skipping" && continue
						(( processedSiteCntr+=1 ))
						if [[ $insertInLine == true ]]; then
							Msg2 "^^$share/$site - $shareType"
							Call "$workerScriptFile" "$siteDir" -clientId $clientId -secondaryMessagesOnly; rc=$?
						else
							siteDirs["$siteDir"]="$clientId"
							keyArray+=("$siteDir")
						fi
					fi
				done
				SetFileExpansion
			fi #[[ $shareType = 'dev' ]]
		done #sites loop
	done #shares loop

#=======================================================================================================================
## If inserts have not already been done then loop through siteDirs array
	if [[ $insertInLine == false ]]; then
		Msg2
		Msg2 "Processed $rawShareCntr server shares"
		[[ ${#keyArray[@]} -eq 0 ]] && Terminate "Zero (0) valid sites found for processing"
		Msg2 "Found ${#keyArray[@]} valid sites..."
		Msg2

		## Sort the keys, loop through the sites processing each
		forkCntr=1;
		keySorted=($(for key in "${keyArray[@]}"; do echo "$key"; done | sort))
		Msg2 "Processing siteDirs via '$workerScript'...";
		for key in "${keySorted[@]}"; do
			#echo -e "\t[$key] = >${siteDirs[$key]}<"
			[[ $fork == true ]] && Msg2 "^Forking: $key" || Msg2 "^Processing: $key "
			if [[ $fork == true ]]; then
				(Call "$workerScriptFile" "$key" -clientId ${siteDirs["$key"]} -secondaryMessagesOnly) &
				(( forkCntr+=1 ))
				## Wait for forked process to finish, only run maxForkedProcesses at a time
				if [[ $((forkCntr%$maxForkedProcesses)) -eq 0 ]]; then
					[[ $batchMode != true ]] && Msg2 "Waiting on forked processes, processed $forkCntr of $processedSiteCntr ..."
					wait
				fi
			else
				Call "$workerScriptFile" "$key" -clientId ${siteDirs["$key"]} -secondaryMessagesOnly
			fi
		done

		## Wait for al the forked tasks to stop
		if [[ $fork == true ]]; then
			[[ $batchMode != true ]] && Msg2 "Waiting for all forked processes to complete..."
			wait
		fi
	fi

#=======================================================================================================================
## How many did we do
	Msg2
	Msg2 "Processed $rawShareCntr server shares"
	Msg2 "^Found $processedShareCntr valid shares"
	Msg2
	Msg2 "Processed $rawSiteCntr directories"
	Msg2 "^Found $processedSiteCntr Courseleaf site directories"
	Msg2
	sqlStmt="select count(*) from $siteInfoTable where host=\"$hostName\"";
	RunSql 'mysql' "$sqlStmt"
	if [[ ${resultSet[0]} -ne 0 ]]; then
		Msg2 "Added ${resultSet[0]} records to $warehouseDb/$siteInfoTable"
	else
		Msg2 $W "No records were inserted into in the $warehouseDb.$siteInfoTable table"
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
