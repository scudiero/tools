#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.2.28 # -- dscudiero -- Fri 05/11/2018 @ 13:56:05.40
#=======================================================================================================================
# Run every hour from cron
#=======================================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 08-30-13 - dgs - Initial coding
# 07-23-15 - dgs - Migrated to framework5
# 12-18-15 - dgs - New structure
# 09-05-17 - dgs - Added '--ignore-date' to rsyc options in SyncSkeleton
#=======================================================================================================================
TrapSigs 'on'
myIncludes='GetPW ProtectedCall CalcElapsed'
Import "$standardIncludes $myIncludes"

originalArgStr="$*"

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd $originalArgStr
scriptArgs="$*"

#=======================================================================================================================
# local functions
#=======================================================================================================================
# Synchronize the internal database shadow with master
function SyncInternalDb {
	srcDir=$clientsTransactionalDb
	tgtDir=$internalContactsDbShadow
	SetFileExpansion 'on'
	rsync -aq $srcDir/* $tgtDir > /dev/null 2>&1
	chmod 770 $tgtDir
	chmod 770 $tgtDir/*
	touch $tgtDir/.syncDate
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion
	return 0
}

#=======================================================================================================================
# Synchronize the courseleaf cgi's  shadow with master
function SyncCourseleafCgis {
	srcDir=/mnt/dev6/web/cgi
	tgtDir=$cgisRoot
	rsync -aq $srcDir/ $tgtDir 2>&1
	chmod 750 $tgtDir
	touch $tgtDir/.syncDate
	SetFileExpansion 'on'
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion
	return 0
}

#=======================================================================================================================
# Synchronize the skeleton shadow with master
function SyncSkeleton {
	srcDir=/mnt/dev6/web/_skeleton
	#srcDir=/steamboat/leepfrog/clskel
	tgtDir=$skeletonRoot

	chmod 770 $tgtDir
	## Build exculde file
		rsyncFilters=/tmp/$userName.rsyncFilters.txt
		if [[ -f $rsyncFilters ]]; then rm $rsyncFilters; fi
		printf "%s\n" '- /attic/' >> $rsyncFilters
		printf "%s\n" '- /requestlog*' >> $rsyncFilters
		printf "%s\n" '- *.bak' >> $rsyncFilters
		printf "%s\n" '- *.old' >> $rsyncFilters

	## sychronize master with shadow
		rsyncOpts="-av --prune-empty-dirs $listOnly --include-from --ignore-date $rsyncFilters"
		rsync $rsyncOpts $srcDir/ $tgtDir > /dev/null 2>&1
		chmod 750 $tgtDir
		touch $tgtDir/.syncDate
		if [[ -f $rsyncFilters ]]; then rm $rsyncFilters; fi
		SetFileExpansion 'on'
		cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
		SetFileExpansion

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
} #SyncSkeleton

#=======================================================================================================================
# Check Monitored files for changes
function CheckMonitorFiles {
	local tmpFile=$(MkTmpFile $FUNCNAME)

	declare -A userNotifies
	## Get a list of currently defined monitoried files
		sqlStmt="select file,userlist from monitorfiles where host=\"$hostName\""
		RunSql "$sqlStmt"
		monitorRecs=("${resultSet[@]}")

		for monitorRec in "${monitorRecs[@]}"; do
			#dump -n monitorRec
			file=$(cut -d'|' -f1 <<< $monitorRec)
			lastModTime=$(stat -c %Y $file)
			userList=$(cut -d'|' -f2 <<< $monitorRec)
			## Loop through the users in the userList
			for user in $(tr ',' ' ' <<< $userList); do
				#dump -t user
				## Check to see if the file has changed since the last time we processed this user/file combo
				sqlStmt="select idx from $newsInfoTable where object=\"$file\" and userName=\"$user\" and edate < $lastModTime"
				RunSql "$sqlStmt"
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					## Update the checked time for this user/file combo
					sqlStmt="update $newsInfoTable set date=NOW(),edate=\"$(date +%s)\" where idx=\"${resultSet[0]}\""
					RunSql "$sqlStmt"
					## Add to this users associateive array
					if [[ ${userNotifies[$user]+abc} ]]; then
						userNotifies["$user"]="${userNotifies[$user]}|$file"
					else
						userNotifies["$user"]="$file"
					fi
				fi
			done ## users
		done ## monitor files

	## Send out the emails
		## Loop throug the associateive array
		for key in "${!userNotifies[@]}"; do
			#echo -e "[$key] = >${userNotifies[$key]}<\n"
			echo -e "The following monitored files have changed:" > $tmpFile
			echo -e >> $tmpFile
			for file in $(tr '|' ' '<<< ${userNotifies[$key]}); do
				echo -e "\t$file" >> $tmpFile
			done
			echo -e >> $tmpFile
			$DOIT mutt -F $tmpFile.2 -s "File Monitor Notice" -- $user@leepfrog.com < $tmpFile
		done;

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
} #CheckMonitorFiles

#=======================================================================================================================
# function BuildToolsAuthTable() {
# 	local tmpFile=$(MkTmpFile $FUNCNAME)
# 	## Build the toolsgroups table from the role data from the stage-internal site
# 		pw=$(GetPW 'stage-internal')
# 		[[ $pw == '' ]] && Terminate "Could not lookup password for 'stage-internal' in password file.\n"
# 		rolesFileURL="https://stage-internal.leepfrog.com/pagewiz/roles.tcf"
# 		curl -u $userName:$pw $rolesFileURL 2>/dev/null | grep '^role:' | cut -d ":" -f 2 > $tmpFile
# 		if [[ ${myRhel:0:1} -ge 6 ]]; then
# 			readarray -t roles < $tmpFile
# 		else 
# 			while read line; do roles+=("$line"); done < $tmpFile
# 		fi

# 		if [[ ${#roles[@]} -gt 0 ]]; then
# 			## Clear out db table
# 				sqlStmt="truncate $authGroupsTable"
# 				RunSql "$sqlStmt"
# 			## Insert auth records
# 				i=0
# 				for roleStr in "${roles[@]}"; do
# 					roleName=$(echo $roleStr | cut -d "|" -f1)
# 					roleCode="$(Lower $roleName | tr -d ' ')"
# 					roleMembers=','$(echo $roleStr | cut -d "|" -f2)','
# 					values="NULL,\"$roleCode\",\"$roleName\",\"$roleMembers\""
# 					#dump -t -n roleStr -t roleCode roleName roleMembers values
# 					sqlStmt="insert into $authGroupsTable values ($values)"
# 					RunSql "$sqlStmt"
# 					(( i+=1 ))
# 				done
# 		else
# 			Msg "W No roles recovered from $rolesFileURL"
# 		fi

# 		[[ -f "$tmpFile" ]] && rm "$tmpFile"
# 	return 0
# } #BuildToolsAuthTable

#=======================================================================================================================
# Sync the courseleaf patch control table from internal to the data warehouse
#=======================================================================================================================
function SyncCourseleafPatchTable() {
	local numfields fields 
	Import 'DatabaseUtilities SetFileExpansion RunSql'

	getTableColumns "$patchesTable" 'warehouse' 'numFields' 'fields'

	## Make a copy of the table
		sqlStmt="drop table if exists ${patchesTable}New"
		RunSql $sqlStmt
		sqlStmt="create table ${patchesTable}New like ${patchesTable}"
		RunSql $sqlStmt

	## Load the data from the transactional table into the new table
		## Get transactional data
		SetFileExpansion 'off'
		sqlStmt="select * from $patchesTable"
		RunSql "$patchControlDb" $sqlStmt
		SetFileExpansion
		for rec in "${resultSet[@]}"; do dataRecs+=("$rec"); done
		## Insert into warehouse table
		for ((i=0; i<${#dataRecs[@]}; i++)); do
			sqlStmt="insert into ${patchesTable}New ($fields) values("
			data="${dataRecs[$i]}"; #data="${data#*|}"
			#sqlStmt="${sqlStmt}null,\"${data//|/","}\")"
			sqlStmt="${sqlStmt}\"${data//|/","}\")"
			RunSql $sqlStmt
		done

	## Swap tables
		sqlStmt="drop table if exists ${patchesTable}Bak"
		RunSql $sqlStmt
		sqlStmt="rename table $patchesTable to ${patchesTable}Bak"
		RunSql $sqlStmt
		sqlStmt="rename table ${patchesTable}New to $patchesTable"
		RunSql $sqlStmt
	return 0
} #SyncCourseleafPatchTable

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
		## Run perftest on even numberd hours
		# if [[ $(( $(date +"%-H") % 2 )) -eq 0 ]]; then
		# 	## Make sure we have a sites table before running perfTest
		# 	sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
		# 	RunSql $sqlStmt
		# 	[[ ${#resultSet[@]} -gt 0 ]] && FindExecutable -sh -run perfTest
		# fi

		## Run programs/functions
			pgms=(updateDefaults SyncCourseleafPatchTable CheckMonitorFiles SyncInternalDb SyncCourseleafCgis SyncSkeleton)
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done

			if [[ $(date "+%H") == 12 ||  $(date "+%H") == 22 ]]; then
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."
				TrapSigs 'off'
				if [[ $(date "+%H") == 12 ]]; then 
					Msg "\n$(date +"%m/%d@%H:%M") - Running syncCourseleafGitRepos master..."
					TrapSigs 'off'; FindExecutable -sh -run syncCourseleafGitRepos master; TrapSigs 'on'
					Msg "...syncCourseleafGitRepos done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
				fi
				if [[ $(date "+%H") == 22 ]]; then 
					Msg "\n$(date +"%m/%d@%H:%M") - Running backupData ..."
					TrapSigs 'off'; FindExecutable -sh -uselocal -run backupData; TrapSigs 'on'
					Msg "...backupData done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
					## Remove all hourly log files older than 24 hrs
					pushd "$(dirname "$logFile")" >& /dev/null
					find . -mtime +0 -exec rm -f '{}' \;
					popd >& /dev/null
				fi
			fi
		;;
	*)
		# sleep 60 ## Wait for perfTest on Mojave to set its semaphore
		# ## Run perftest on even numberd hours
		# if [[ $(( $(date +"%-H") % 2 )) -eq 0 ]]; then
		# 	## Make sure we have a sites table before running perfTest
		# 	sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
		# 	RunSql $sqlStmt
		# 	if [[ ${#resultSet[@]} -gt 0 ]]; then
		# 		Semaphore 'waiton' 'perfTest'
		# 		FindExecutable -sh -run perfTest
		# 		FindExecutable -sh -run perfTest summary
		# 	fi
		# fi
		## Run programs/functions
			pgms=(CheckMonitorFiles)
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done
		;;
esac

#=======================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Dec 29 11:51:43 CST 2016 - dscudiero - x
## Thu Dec 29 12:01:46 CST 2016 - dscudiero - Switched to use the RunSql java program
## Thu Jan  5 14:49:52 CST 2017 - dscudiero - Switch to use RunSql
## Wed Jan 25 08:03:11 CST 2017 - dscudiero - change location of internalDb shadow
## Wed Jan 25 09:33:50 CST 2017 - dscudiero - pull location of internals db shadow from defaults
## Fri Jan 27 08:00:12 CST 2017 - dscudiero - Add perftest
## Fri Jan 27 14:21:16 CST 2017 - dscudiero - Add perftest summary record generation
## Fri Jan 27 14:29:55 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Feb  3 11:28:29 CST 2017 - dscudiero - Change Msg2; Msg to echo; Msg2
## Mon Feb  6 09:19:58 CST 2017 - dscudiero - Remove debug message
## Tue Feb  7 15:15:13 CST 2017 - dscudiero - allow file expansion for the chgrp in syncskeleton
## Thu Feb  9 08:07:08 CST 2017 - dscudiero - Check to make sure there is a sites table before running perftest
## Wed Feb 15 07:09:08 CST 2017 - dscudiero - Turn on file expansion before chgrp commands
## Fri Feb 17 06:58:55 CST 2017 - dscudiero - Add a waiton perftest on build7
## Tue Feb 21 13:31:38 CST 2017 - dscudiero - Fix query checking for the sites table
## Wed Feb 22 15:22:49 CST 2017 - dscudiero - Only run perftest on even numered hours
## Fri Feb 24 09:39:09 CST 2017 - dscudiero - Fix a problem checking if the hour was an even hour
## Tue Mar  7 07:33:11 CST 2017 - dscudiero - Ignore messages from rsync for SyncInternalDb
## 05-19-2017 @ 07.26.44 - (2.1.116)   - dscudiero - add call to reports as a test
## 05-19-2017 @ 08.55.20 - (2.1.118)   - dscudiero - Added debug stuff
## 05-19-2017 @ 11.21.55 - (2.1.120)   - dscudiero - add debug code to build7
## 05-19-2017 @ 12.25.58 - (2.1.121)   - dscudiero - added debug
## 08-18-2017 @ 17.06.16 - (2.1.122)   - dscudiero - Added call to backupData
## 09-05-2017 @ 08.56.21 - (2.1.123)   - dscudiero - Added '--ignore-date' to rsync options for syncskeleton
## 09-08-2017 @ 08.11.31 - (2.1.124)   - dscudiero - Update imports
## 09-08-2017 @ 11.26.25 - (2.1.125)   - dscudiero - add protectedcall to the list of includes
## 09-12-2017 @ 07.42.46 - (2.1.126)   - dscudiero - set USELOCAL before call of backupdata
## 09-21-2017 @ 08.17.52 - (2.1.127)   - dscudiero - comment out updateauthtable
## 09-28-2017 @ 08.49.42 - (2.1.129)   - dscudiero - Modify calls to updateDefaults to add mode
## 10-10-2017 @ 16.20.35 - (2.1.131)   - dscudiero - Swap out usage of Call
## 10-11-2017 @ 07.42.13 - (2.1.133)   - dscudiero - Update to use FindExecutable with the -run option
## 10-11-2017 @ 09.55.29 - (2.1.134)   - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 10.21.34 - (2.1.135)   - dscudiero - Add HERE statement
## 10-11-2017 @ 10.37.31 - (2.1.137)   - dscudiero - Switch to use FindExecutable -run
## 10-12-2017 @ 14.43.02 - (2.1.137)   - dscudiero - Cosmetic/minor change
## 10-12-2017 @ 14.44.26 - (2.2.0)     - dscudiero - Cosmetic/minor change
## 10-13-2017 @ 14.37.27 - (2.2.1)     - dscudiero - Add debug stuff
## 10-16-2017 @ 13.16.18 - (2.2.2)     - dscudiero - Fix syntax error
## 10-16-2017 @ 13.16.46 - (2.2.3)     - dscudiero - remove debug statements
## 10-16-2017 @ 13.18.32 - (2.2.4)     - dscudiero - Cosmetic/minor change
## 10-16-2017 @ 13.46.10 - (2.2.5)     - dscudiero - Add debug
## 10-16-2017 @ 15.03.55 - (2.2.6)     - dscudiero - Remove debug statements
## 10-25-2017 @ 09.14.38 - (2.2.7)     - dscudiero - Refactored to new structure
## 10-25-2017 @ 11.05.31 - (2.2.8)     - dscudiero - Add standardIncludes to the includes list
## 10-26-2017 @ 11.13.14 - (2.2.9)     - dscudiero - Remove extra 'starting' messages from the functions
## 10-26-2017 @ 12.16.52 - (2.2.10)    - dscudiero - Tweak messaging
## 10-26-2017 @ 16.03.14 - (2.2.12)    - dscudiero - add messaging arround the 12 noon and 22 hour calls
## 10-27-2017 @ 07.02.09 - (2.2.13)    - dscudiero - Fix syntax error introduced with last update
## 10-27-2017 @ 07.15.15 - (2.2.14)    - dscudiero - Misc cleanup
## 10-27-2017 @ 07.30.18 - (2.2.15)    - dscudiero - Cleanup old log files every night
## 10-27-2017 @ 08.08.03 - (2.2.16)    - dscudiero - Use CalcElapsed function to calculate elapsed times
## 10-30-2017 @ 07.43.44 - (2.2.17)    - dscudiero - Tweak messaging
## 12-06-2017 @ 11.16.14 - (2.2.18)    - dscudiero - Refactored building the defaults data files
## 03-22-2018 @ 12:46:57 - 2.2.19 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 12:08:55 - 2.2.20 - dscudiero - Comment out perfTest
## 03-23-2018 @ 15:33:56 - 2.2.22 - dscudiero - D
## 03-23-2018 @ 16:18:31 - 2.2.23 - dscudiero - Cleanup Includes
## 03-26-2018 @ 08:56:02 - 2.2.25 - dscudiero - Comment out BuildToolsAuthTable
## 05-04-2018 @ 13:32:00 - 2.2.26 - dscudiero - Added SyncCourseleafPatchTable function
## 05-08-2018 @ 08:14:10 - 2.2.27 - dscudiero - Update syncCourseLeafPatchTable to chage name of the transactional db
## 05-21-2018 @ 07:22:15 - 2.2.28 - dscudiero - Switch to clskel
