#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.93 # -- dscudiero -- 12/29/2016 @ 12:01:13.86
#=======================================================================================================================
# Run every hour from cron
#=======================================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 08-30-13 -- dgs - Initial coding
# 07-23-15 -- dgs - Migrated to framework5
# 12-18-15 -- dgs - New structure
#=======================================================================================================================
TrapSigs 'on'
Import FindExecutable GetDefaultsData ParseArgsStd ParseArgs RunSql Msg2 Call GetPW
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
	Msg2; Msg2 "*** $FUNCNAME -- Starting ***"
	srcDir=$clientsTransactionalDb
	tgtDir=$TOOLSPATH/internalContactsDbShadow
	SetFileExpansion 'on'
	rsync -aq $srcDir/* $tgtDir 2>&1
	chmod 770 $tgtDir
	chmod 770 $tgtDir/*
	SetFileExpansion
	touch $tgtDir/.syncDate
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
}

#=======================================================================================================================
# Synchronize the courseleaf cgi's  shadow with master
function SyncCourseleafCgis {
	Msg2; Msg2 "*** $FUNCNAME -- Starting ***"
	srcDir=/mnt/dev6/web/cgi
	tgtDir=$cgisRoot
	rsync -aq $srcDir/ $tgtDir 2>&1
	chmod 750 $tgtDir
	touch $tgtDir/.syncDate
	cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
}

#=======================================================================================================================
# Synchronize the skeleton shadow with master
function SyncSkeleton {
	Msg2; Msg2 "*** $FUNCNAME -- Starting ***"
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
		cwd=$(pwd); cd $tgtDir; chgrp -R leepfrog *; chgrp leepfrog .*; cd "$cwd"
		Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
} #SyncSkeleton

#=======================================================================================================================
# Check Monitored files for changes
function CheckMonitorFiles {
	Msg2; Msg2 "*** $FUNCNAME -- Starting ***"

	declare -A userNotifies
	echo "set realname=\"File Monitor\"" > $tmpFile.2
	## Get a list of currently defined monitoried files
		sqlStmt="select file,userlist from monitorfiles where host=\"$hostName\""
		RunMySql "$sqlStmt"
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
				RunMySql "$sqlStmt"
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					## Update the checked time for this user/file combo
					sqlStmt="update $newsInfoTable set date=NOW(),edate=\"$(date +%s)\" where idx=\"${resultSet[0]}\""
					RunMySql "$sqlStmt"
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

	Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
} #CheckMonitorFiles

#=======================================================================================================================
function BuildToolsAuthTable() {
	Msg2; Msg2 "*** $FUNCNAME -- Starting ***"
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
		[[ -f $tmpFile ]] && rm -f $tmpFile

		if [[ ${#roles[@]} -gt 0 ]]; then
			## Clear out db table
				sqlStmt="truncate $authGroupsTable"
				RunMySql "$sqlStmt"
			## Insert auth records
				i=0
				for roleStr in "${roles[@]}"; do
					roleName=$(echo $roleStr | cut -d "|" -f1)
					roleCode="$(Lower $roleName | tr -d ' ')"
					roleMembers=','$(echo $roleStr | cut -d "|" -f2)','
					values="NULL,\"$roleCode\",\"$roleName\",\"$roleMembers\""
					#dump -t -n roleStr -t roleCode roleName roleMembers values
					sqlStmt="insert into $authGroupsTable values ($values)"
					RunMySql "$sqlStmt"
					(( i+=1 ))
				done
		else
			Msg2 "W No roles recovered from $rolesFileURL"
		fi

		Msg2 "*** $FUNCNAME -- Completed ***"
	return 0
} #BuildToolsAuthTable

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
			CheckMonitorFiles
			SyncInternalDb
			BuildToolsAuthTable
			SyncCourseleafCgis
			SyncSkeleton
			[[ $(date "+%H") == 12 ]] && Call 'syncCourseleafGitRepos' 'master'
			;;
	build5)
			#CheckMonitorFiles -- commented out since build5 does not support 'declare -A'
			;;
	build7)
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
## Thu Dec 29 12:01:46 CST 2016 - dscudiero - Switched to use the RunMySql java program
