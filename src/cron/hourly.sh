#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.121 # -- dscudiero -- Fri 05/19/2017 @ 12:09:37.81
#=======================================================================================================================
# Run every hour from cron
#=======================================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 08-30-13 -- dgs - Initial coding
# 07-23-15 -- dgs - Migrated to framework5
# 12-18-15 -- dgs - New structure
#=======================================================================================================================
TrapSigs 'on'
Import FindExecutable GetDefaultsData ParseArgsStd ParseArgs RunSql2 Msg2 Call GetPW
originalArgStr="$*"

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
scriptArgs="$*"

#=======================================================================================================================
# local functions
#=======================================================================================================================
# Synchronize the internal database shadow with master
function SyncInternalDb {
	echo; Msg2 "*** $FUNCNAME -- Starting ***"
	srcDir=$clientsTransactionalDb
	tgtDir=$internalContactsDbShadow
	SetFileExpansion 'on'
	rsync -aq $srcDir/* $tgtDir > /dev/null 2>&1
	chmod 770 $tgtDir
	chmod 770 $tgtDir/*
	touch $tgtDir/.syncDate
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion
	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
}

#=======================================================================================================================
# Synchronize the courseleaf cgi's  shadow with master
function SyncCourseleafCgis {
	echo; Msg2 "*** $FUNCNAME -- Starting ***"
	srcDir=/mnt/dev6/web/cgi
	tgtDir=$cgisRoot
	rsync -aq $srcDir/ $tgtDir 2>&1
	chmod 750 $tgtDir
	touch $tgtDir/.syncDate
	SetFileExpansion 'on'
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	SetFileExpansion
	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
}

#=======================================================================================================================
# Synchronize the skeleton shadow with master
function SyncSkeleton {
	echo; Msg2 "*** $FUNCNAME -- Starting ***"
	srcDir=/mnt/dev6/web/_skeleton
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
		rsyncOpts="-av --prune-empty-dirs $listOnly --include-from $rsyncFilters"
		rsync $rsyncOpts $srcDir/ $tgtDir > /dev/null 2>&1
		chmod 750 $tgtDir
		touch $tgtDir/.syncDate
		if [[ -f $rsyncFilters ]]; then rm $rsyncFilters; fi
		SetFileExpansion 'on'
		cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
		SetFileExpansion

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
} #SyncSkeleton

#=======================================================================================================================
# Check Monitored files for changes
function CheckMonitorFiles {
	echo; Msg2 "*** $FUNCNAME -- Starting ***"
	local tmpFile=$(MkTmpFile $FUNCNAME)

	declare -A userNotifies
	## Get a list of currently defined monitoried files
		sqlStmt="select file,userlist from monitorfiles where host=\"$hostName\""
		RunSql2 "$sqlStmt"
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
				RunSql2 "$sqlStmt"
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					## Update the checked time for this user/file combo
					sqlStmt="update $newsInfoTable set date=NOW(),edate=\"$(date +%s)\" where idx=\"${resultSet[0]}\""
					RunSql2 "$sqlStmt"
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
	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
} #CheckMonitorFiles

#=======================================================================================================================
function BuildToolsAuthTable() {
	local tmpFile=$(MkTmpFile $FUNCNAME)
	echo; Msg2 "*** $FUNCNAME -- Starting ***"

	## Build the toolsgroups table from the role data from the stage-internal site
		pw=$(GetPW 'stage-internal')
		[[ $pw == '' ]] && Msg2 "T Could not lookup password for 'stage-internal' in password file.\n"
		rolesFileURL="https://stage-internal.leepfrog.com/pagewiz/roles.tcf"
		curl -u $userName:$pw $rolesFileURL 2>/dev/null | grep '^role:' | cut -d ":" -f 2 > $tmpFile
		if [[ ${myRhel:0:1} -ge 6 ]]; then
			readarray -t roles < $tmpFile
		else 
			while read line; do roles+=("$line"); done < $tmpFile
		fi

		if [[ ${#roles[@]} -gt 0 ]]; then
			## Clear out db table
				sqlStmt="truncate $authGroupsTable"
				RunSql2 "$sqlStmt"
			## Insert auth records
				i=0
				for roleStr in "${roles[@]}"; do
					roleName=$(echo $roleStr | cut -d "|" -f1)
					roleCode="$(Lower $roleName | tr -d ' ')"
					roleMembers=','$(echo $roleStr | cut -d "|" -f2)','
					values="NULL,\"$roleCode\",\"$roleName\",\"$roleMembers\""
					#dump -t -n roleStr -t roleCode roleName roleMembers values
					sqlStmt="insert into $authGroupsTable values ($values)"
					RunSql2 "$sqlStmt"
					(( i+=1 ))
				done
		else
			Msg2 "W No roles recovered from $rolesFileURL"
		fi

		[[ -f "$tmpFile" ]] && rm "$tmpFile"
		Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
} #BuildToolsAuthTable

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
		## Run perftest on even numberd hours
		if [[ $(( $(date +"%-H") % 2 )) -eq 0 ]]; then
			## Make sure we have a sites table before running perfTest
			sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
			RunSql2 $sqlStmt
			[[ ${#resultSet[@]} -gt 0 ]] && Call 'perfTest'
		fi
		CheckMonitorFiles
		SyncInternalDb
		BuildToolsAuthTable
		SyncCourseleafCgis
		SyncSkeleton
		## If noon then update the git repo shadows
		[[ $(date "+%H") == 12 ]] && Call 'syncCourseleafGitRepos' 'master'
		;;
	*)
		sleep 60 ## Wait for perfTest on Mojave to set its semaphore
		## Run perftest on even numberd hours
		if [[ $(( $(date +"%-H") % 2 )) -eq 0 ]]; then
			## Make sure we have a sites table before running perfTest
			sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
			RunSql2 $sqlStmt
			[[ ${#resultSet[@]} -gt 0 ]] && Semaphore 'waiton' 'perfTest' && Call 'perfTest' && Call 'perfTest' 'summary'
		fi
		CheckMonitorFiles
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
## Thu Dec 29 12:01:46 CST 2016 - dscudiero - Switched to use the RunSql2 java program
## Thu Jan  5 14:49:52 CST 2017 - dscudiero - Switch to use RunSql2
## Wed Jan 25 08:03:11 CST 2017 - dscudiero - change location of internalDb shadow
## Wed Jan 25 09:33:50 CST 2017 - dscudiero - pull location of internals db shadow from defaults
## Fri Jan 27 08:00:12 CST 2017 - dscudiero - Add perftest
## Fri Jan 27 14:21:16 CST 2017 - dscudiero - Add perftest summary record generation
## Fri Jan 27 14:29:55 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Feb  3 11:28:29 CST 2017 - dscudiero - Change Msg2; Msg2 to echo; Msg2
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
