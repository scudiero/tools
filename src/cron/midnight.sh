#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=1.21.188 # -- dscudiero -- 02/10/2017 @ 16:12:25.27
#=======================================================================================================================
# Run nightly from cron
#=======================================================================================================================
TrapSigs 'on'
Import FindExecutable GetDefaultsData ParseArgsStd ParseArgs RunSql2 Msg2 Call RunCoureleafCgi GetCourseleafPgm
originalArgStr="$*";

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
function parseArgs-midnight  { # or parseArgs-$myName
	return 0
}
function Goodbye-midnight  { # or Goodbye-$myName
	SetFileExpansion 'on'
	rm -rf /tmp/$LOGNAME* > /dev/null 2>&1
	SetFileExpansion
	return 0
}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
function CleanToolsBin {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"

	## Setup lower case 'aliases' for the TOOLSPATH/bin commands, remove any links in bin that do not have a source in src
	Msg2; Msg2 "Processing $TOOLSPATH/bin..."
	ignoreFiles=",scripts,reports,"
	cwd=$(pwd)
	cd $TOOLSPATH/bin
	files=$(find . -mindepth 1 -maxdepth 1 -type l -printf "%f ")
	for file in $files; do
		[[ $(Contains "$ignoreFiles" "$file") == true ]] && continue
		[[ ! -f $TOOLSPATH/src/${file}.sh && ! -f $TOOLSPATH/src/${file}.py && ! -f $TOOLSPATH/src/${file}.pl ]] && Msg2 $WT1 "Removing: $file" && rm ../src/$file && continue
		[[ $file != $(Lower "$file") ]] && Msg2 "^Makeing link: $(Lower "$file")" && ln -s ./$file ./$(Lower "$file")
	done
	cd "$cwd"

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #CleanToolsBin

#=======================================================================================================================
function CheckClientCount {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	## Get number of clients in transactional
	SetFileExpansion 'off'
	sqlStmt="select count(*) from clients where is_active=\"Y\""
	RunSql2 "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients data from '$contactsSqliteFile'"
	else
		tCount=${resultSet[0]}
	fi
	## Get number of clients in warehouse
	sqlStmt="select count(*) from $clientInfoTable where recordstatus=\"A\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		wCount=${resultSet[0]}
	fi
	## Get number of clients on the ignore list
	sqlStmt="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		let numIgnore=$(grep -o "," <<< "${resultSet[0]}r" | wc -l)+1
		let tCount=$tCount-$numIgnore
	fi
	SetFileExpansion
	if [[ $tCount -gt $wCount ]]; then
		Msg2 "$FUNCNAME: New clients found in the transactional clients table, running 'clientList' report..."
		echo true
	else
		echo false
	fi
	return 0
} #CheckClientCount

#=======================================================================================================================
function BuildEmployeeTable {
	Msg2 "$FUNCNAME -- Starting"

	## Create a temp table to load into
		sqlStmt="drop table if exists ${employeeTable}New"
		RunSql2 $sqlStmt
		sqlStmt="create table ${employeeTable}New like ${employeeTable}"
		RunSql2 $sqlStmt

	### Get the list of columns in the transactional employees table
		sqlStmt="pragma table_info(employees)"
		RunSql2 "$contactsSqliteFile" $sqlStmt
		unset transactionalFields transactionalColumns
		for resultRec in "${resultSet[@]}"; do
			transactionalColumns="$transactionalColumns,$(cut -d'|' -f2 <<< $resultRec)"
			transactionalFields="$transactionalFields,$(cut -d'|' -f2 <<< $resultRec)|$(cut -d'|' -f3 <<< $resultRec)"
		done
		transactionalColumns=${transactionalColumns:1}
		transactionalFields=${transactionalFields:1}

	### Get the transactonal values, loop through them and  write out the warehouse record
		sqlStmt="select $transactionalColumns from employees where db_isactive = \"Y\" order  by db_employeekey"
		RunSql2 "$contactsSqliteFile" $sqlStmt
		for resultRec in "${resultSet[@]}"; do
			fieldCntr=1; unset valuesString
			for field in $(tr ',' ' ' <<< $transactionalFields); do
				column=$(cut -d'|' -f1 <<< $field)
				columnType=$(cut -d'|' -f2 <<< $field)
				eval "unset $column"
				eval "$column=\"$(cut -d '|' -f $fieldCntr <<< $resultRec)\""
				[[ $columnType == 'INTEGER' ]] && valuesString="$valuesString,${!column}" || valuesString="$valuesString,\"${!column}\""
				(( fieldCntr += 1 ))
			done
			valuesString=${valuesString:1}
			sqlStmt="insert into ${employeeTable}New values($valuesString)"
			RunSql2 $sqlStmt
		done

	## Swap temp table for the real table
		sqlStmt="select count(*) from ${employeeTable}New"
		RunSql2 $sqlStmt
		newCnt=${resultSet[0]}
		sqlStmt="select count(*) from ${employeeTable}"
		RunSql2 $sqlStmt
		oldCnt=${resultSet[0]}
		let countDiff=$oldCnt-$newCnt
		let oneFourthsPrev=$oldCnt/4
		if [[ $newCnt -eq 0 || $countDiff -gt $oneFourthsPrev ]]; then
			Error "New employee table is significantly smaller than the origional, keeping origional"
		else
			sqlStmt="drop table if exists ${employeeTable}Bak"
			RunSql2 $sqlStmt
			sqlStmt="rename table ${employeeTable} to ${employeeTable}Bak"
			RunSql2 $sqlStmt
			sqlStmt="rename table ${employeeTable}New to ${employeeTable}"
			RunSql2 $sqlStmt
			# sqlStmt="drop table if exists ${employeeTable}Bak"
			# RunSql2 $sqlStmt
		fi

	Msg2 "$FUNCNAME -- Completed"
	return 0
} #BuildEmployeeTable

#=======================================================================================================================
function BuildCourseleafDataTable {
	Msg2 "$FUNCNAME -- Starting"

	## Clean out the existing data
	sqlStmt="truncate $courseleafDataTable"
	RunSql2 $sqlStmt

	## Get Courseleaf component versions
		components=($(find $gitRepoShadow -maxdepth 1 -mindepth 1 -type d -printf "%f "))
		for component in "${components[@]}"; do
			dirs=($(ls -t $gitRepoShadow/$component | ProtectedCall "grep -v master"))
			[[ ${#dirs[@]} -gt 0 ]] && latest=${dirs[0]} || latest='master'
			dump -1 component latest
			sqlStmt="insert into $courseleafDataTable values(NULL,\"$component\",NULL,\"$latest\",NOW(),\"$userName\")"
			RunSql2 $sqlStmt
		done

	## Get Courseleaf Reports versions
		cwd=$(pwd)
		cd "$courseleafReportsRoot"
		SetFileExpansion 'on';
		local reportsVersions=$(ls -d -t * 2> /dev/null | cut -d $'\n' -f1);
		cd $courseleafReportsRoot/$reportsVersions
		reportsVersions=$(ls -d -t * 2> /dev/null | cut -d $'\n' -f1);
		reportsVersions=$(cut -d'.' -f1-3 <<< $reportsVersions)
		SetFileExpansion
		dump -1 reportsVersions
		sqlStmt="insert into $courseleafDataTable values(NULL,\"reports\",NULL,\"$reportsVersions\",NOW(),\"$userName\")"
		[[ -n $reportsVersions ]] && RunSql2 $sqlStmt
		cd "$cwd"

	## Get daily.sh versions
		dailyshVer=$(ProtectedCall "grep 'version=' $skeletonRoot/release/bin/daily.sh")
		dailyshVer=${dailyshVer##*=} ; dailyshVer=${dailyshVer%% *}
		dump -1 dailyshVer
		sqlStmt="insert into $courseleafDataTable values(NULL,\"daily.sh\",NULL,\"$dailyshVer\",NOW(),\"$userName\")"
		[[ -n $dailyshVer ]] && RunSql2 $sqlStmt

	## Get Courseleaf cgi versions
		cwd=$(pwd)
		cd $cgisRoot
		for rhelDir in $(ls | grep '^rhel[0-9]$'); do
			dirs=($(ls -c ./$rhelDir | ProtectedCall "grep -v prev_ver"))
			[[ ${#dirs[@]} -gt 0 ]] && latest=${dirs[0]} || latest='master'
			if [[ $latest != 'master' ]]; then
				cd $rhelDir/$latest
				[[ -r ./courseleaf.log ]] && cgiVer=$(cat courseleaf.log | cut -d'|' -f5) || cgiVer=$latest
				cd $cgisRoot
			else
				cgiVer=$latest
			fi
			dump -1 rhelDir cgiVer
			sqlStmt="insert into $courseleafDataTable values(NULL,\"courseleaf.cgi\",\"$rhelDir\",\"$cgiVer\",NOW(),\"$userName\")"
			RunSql2 $sqlStmt
		done

	## Rebuild the page
		cwd=$(pwd)
		cd /mnt/internal/site/stage/web/pagewiz
		$DOIT ./pagewiz.cgi -r /support/courseleafData
		cd $cwd

	Msg2 "$FUNCNAME -- Completed"
	return 0
} #BuildCourseleafDataTable

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
scriptArgs="$*"
logInDb=false

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
		## Performance test
			Msg2 "Running perfTest..."
			## Set a semaphore
				sqlStmt="insert into $semaphoreInfoTable values(NULL,\"perfTest\",\"$hostName\",\"$LOGNAME\",NOW())"
				RunSql2 $sqlStmt
			Call 'perfTest'
			## Clear buildClientInfoTable semaphore
				sqlStmt="delete from $semaphoreInfoTable where processName=\"perfTest\" and hostName=\"$hostName\""
				RunSql2 $sqlStmt

		## Compare number of clients in the warehouse vs the transactional if more in transactional then runClientListReport=true
			runClientListReport=$(CheckClientCount)

		## Copy the contacts db from internal
			Msg2 "Copying contacts.sqlite files to $sqliteDbs/contacts.sqlite..."
			cd $clientsTransactionalDb
			cp $clientsTransactionalDb/contacts.sqlite $sqliteDbs/contacts.sqlite
			touch $sqliteDbs/contacts.syncDate
			Msg2 "^...done"

		Msg2 "Running BuildClientInfoTable..."
		## Build the clientInfoTable
			## Set a semaphore
				sqlStmt="insert into $semaphoreInfoTable values(NULL,\"buildClientInfoTable\",\"$hostName\",\"$LOGNAME\",NOW())"
				RunSql2 $sqlStmt
			Call 'buildClientInfoTable' "$scriptArgs"

		## Check to see of clients table has data
			sqlStmt="select count(*) from $clientInfoTable"
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				Error "Clients table is empty, skipping 'buildSiteInfoTable', semaphore kept in place"
			else
				## Clear buildClientInfoTable semaphore
				sqlStmt="delete from $semaphoreInfoTable where processName=\"buildClientInfoTable\" and hostName=\"$hostName\""
				RunSql2 $sqlStmt

				## Set a semaphore for this servers call to buildSiteInfoTable
				sqlStmt="insert into $semaphoreInfoTable values(NULL,\"buildSiteInfoTable\",\"$hostName\",\"$LOGNAME\",NOW())"
				RunSql2 $sqlStmt

				## Create a temporary copy of the sites table, load new data to that table, backup master table
				for table in $siteInfoTable $siteAdminsTable; do
					sqlStmt="drop table if exists ${table}Bak"
					RunSql2 $sqlStmt
					sqlStmt="drop table if exists ${table}New"
					RunSql2 $sqlStmt
					sqlStmt="create table ${table}New like ${table}"
					RunSql2 $sqlStmt
					sqlStmt="rename table ${table} to ${table}Bak"
					RunSql2 $sqlStmt
				done

				## Clear buildClientInfoTable semaphore, allowing processes on other hosts to start
				sqlStmt="delete from $semaphoreInfoTable where processName=\"buildSiteInfoTable\""
				RunSql2 $sqlStmt

				## Build siteinfotabe and siteadmins table
				Call 'buildSiteInfoTable' "-table ${siteInfoTable}New $scriptArgs"

				## Clear buildSiteInfoTable semaphore
				sqlStmt="delete from $semaphoreInfoTable where processName=\"buildSiteInfoTable\" and hostName=\"$hostName\""
				RunSql2 $sqlStmt
		fi
		Msg2 "^...(Running BuildClientInfoTable) done"

		## Wait for all of the buildSiteInfoTable process to finish
			waitCntr=1 ; let maxLoop=2*2*60+30*2 ## 2.5 hours
			while [[ $waitCntr -lt $maxLoop ]]; do    # Wait no longer than X
				sleep 30 ## Wait for process to start on mojave and get the semaphore set
				## Check 'buildClientsInfoTable' semaphore, wait for truncate to be done on mojave
				sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"buildSiteInfoTable\""
				RunSql2 $sqlStmt
				[[ ${resultSet[@]} -eq 0 ]] && break
				echo -e "\tWaiting for all buildSiteInfoTable process to complete, waitCntr=$waitCntr\t$(date)"
				((waitCntr++))
			done
			if [[ $waitCntr -ge $maxLoop ]]; then
				Error "Wait for buildSiteInfoTables to complete timed out, activating original '$siteInfoTable'"
				for table in $siteInfoTable $siteAdminsTable; do
					sqlStmt="drop table if exists ${table}New"
					RunSql2 $sqlStmt
					sqlStmt="rename table ${siteInfoTable}Bak to $siteInfoTable"
					RunSql2 $sqlStmt
				done
			else
				sqlStmt="rename table ${siteInfoTable}New to $siteInfoTable"
				RunSql2 $sqlStmt
				sqlStmt="rename table ${siteAdminsTable}New to $siteAdminsTable"
				RunSql2 $sqlStmt
			fi

		## Build employee table
			BuildEmployeeTable

		## Build the courseleafData table
			BuildCourseleafDataTable

		## Build the qaStatus table
			Call 'buildQaStatusTable' "$scriptArgs"

		## Common Checks
			Call 'checkCgiPermissions' "$scriptArgs"
			Call 'checkPublishSettings' "$scriptArgs"

		## Update the defaults data for this host
			Call 'updateDefaults' "$scriptArgs"

		## rebuild Internal pages to pickup any new database information
			Msg2 "Rebuilding Internal pages"
			RunCoureleafCgi "$stageInternal" "-r /clients"
			RunCoureleafCgi "$stageInternal" "-r /support/tools"
			RunCoureleafCgi "$stageInternal" "-r /support/qa"

		## On the last day of the month roll-up the log files
		  	if [[ $(date +"%d") == $(date -d "$(date +"%m")/1 + 1 month - 1 day" "+%d") ]]; then
		  		Msg2 "Rolling up monthly log files"
				cd $TOOLSPATH/Logs
				SetFileExpansion 'on'
				tar -cvzf "$(date '+%b-%Y').tar.gz" $(date +"%m")-* --remove-files > /dev/null 2>&1
				SetFileExpansion
		  	fi

		## Scratch copy the skeleton shadow
			Msg2 "Scratch copying the skeleton shadow..."
			chmod u+wx $skeletonRoot
			SetFileExpansion 'on'
			rm -rf $skeletonRoot/*
			rsyncOpts="-a --prune-empty-dirs"
			rsync $rsyncOpts /mnt/dev6/web/_skeleton/* $skeletonRoot
			SetFileExpansion
			touch $skeletonRoot/.syncDate
			Msg2 "^...done"

		## Build a sqlite clone of the data warehouse
			Call 'buildWarehouseSqlite' "$scriptArgs"

		## Clean up the tools bin directory.
			#CleanToolsBin

		## Sync GIT Shadow
			Call 'syncCourseleafGitRepos' "$scriptArgs"

		## Create a clone of the warehouse db
			Msg2 "Creating '$warehouseDev' database..."
			tmpConnectString=$(sed "s/Read/Admin/" <<< ${mySqlConnectString% *})

			mysqldump $tmpConnectString $warehouseProd > /tmp/warehouse.sql;
			mysql $tmpConnectString -e "drop database if exists $warehouseDev"
			mysqladmin $tmpConnectString create $warehouseDev

			mysql $tmpConnectString $warehouseDev < /tmp/warehouse.sql
			[[ -f /tmp/warehouse.sql ]] && rm -f /tmp/warehouse.sql

		## Reports
			froggerQa='sjones@leepfrog.com,mbruening@leepfrog.com,jlindeman@leepfrog.com'
			Call 'reports' "qaStatus -email "dscudiero@leepfrog.com,$froggerQa" $scriptArgs"
			## Build a list of clients and contact info for Shelia
			[[ $runClientListReport == true ]] && Call 'reports' "clientList -quiet -email 'dscudiero@leepfrog.com,sfrickson@leepfrog.com' $scriptArgs"

		;; ## mojave

	*) ## build7
		## Wait for the perftest process to complete
		waitCntr=1 ; let maxLoop=1*60*60/30 # Number of hours * 60 min/hr * 60 sec/min / sleep time
		while [[ $waitCntr -lt $maxLoop ]]; do    # Wait no longer than X
			sleep 30
			## Check 'perfTest' semaphore, wait for truncate to be done on mojave
			sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"perfTest\""
			RunSql2 $sqlStmt
			[[ ${resultSet[@]} -eq 0 ]] && break
			((waitCntr++))
		done
		if [[ $waitCntr -ge $maxLoop ]]; then
			Error "Wait for perfTest to complete timed out, skipping 'perfTest' on $hostName"
		else
			Call 'perfTest'
			Call 'perfTest' 'summary'
		fi

		## Wait for the buildClientsInfoTable process to complete on mojave
		waitCntr=1 ; let maxLoop=1*60*60/30 # Number of hours * 60 min/hr * 60 sec/min / sleep time
		while [[ $waitCntr -lt $maxLoop ]]; do    # Wait no longer than X
			sleep 30
			sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"buildClientsInfoTable\""
			RunSql2 $sqlStmt
			[[ ${resultSet[@]} -eq 0 ]] && break
			echo -e "\tWaiting for all buildClientsInfoTable process to complete, waitCntr=$waitCntr\t$(date)"
			((waitCntr++))
		done
		if [[ $waitCntr -ge $maxLoop ]]; then
			Error "Wait for buildClientsInfoTable to complete timed out, skipping load of '$siteInfoTable'"
		else
			## Build $siteInfoTable and $siteAdminsTable tables
			## Set a semaphore for this servers call to buildSiteInfoTable
			sqlStmt="insert into $semaphoreInfoTable values(NULL,\"buildSiteInfoTable\",\"$hostName\",\"$LOGNAME\",NOW())"
			RunSql2 $sqlStmt
			Call 'buildSiteInfoTable' "-table sitesNew $scriptArgs"
			## Clear buildSiteInfoTable semaphore
			sqlStmt="delete from $semaphoreInfoTable where processName=\"buildSiteInfoTable\" and hostName=\"$hostName\""
			RunSql2 $sqlStmt
		fi

		## Wait for the all buildSiteInfoTable process to complete
			waitCntr=1 ; let maxLoop=2*60*60/30 # Number of hours * 60 min/hr * 60 sec/min / sleep time
			while [[ $waitCntr -lt $maxLoop ]]; do    # Wait no longer than X
				sleep 30
				sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"buildSiteInfoTable\""
				RunSql2 $sqlStmt
				[[ ${resultSet[@]} -eq 0 ]] && break
				echo -e "\tWaiting for all buildSiteInfoTable process to complete, waitCntr=$waitCntr\t$(date)"
				((waitCntr++))
			done
			if [[ $waitCntr -ge $maxLoop ]]; then
				Terminate "Wait for buildSiteInfoTable processes to complete timed out"
			else

		## Common Checks
			Call 'checkCgiPermissions' "$scriptArgs"
		## Update the defaults data for this host
			Call 'updateDefaults' "$scriptArgs"
		;;
esac

#=======================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
Msg2 "\n$myName: Done\n"
return 0

#=======================================================================================================================
# Change Log
#=======================================================================================================================
## Thu Dec 29 12:00:02 CST 2016 - dscudiero - General syncing of dev to prod
## Thu Dec 29 14:44:17 CST 2016 - dscudiero - Switch to use RunMySql
## Thu Dec 29 15:26:23 CST 2016 - dscudiero - tsting
## Thu Dec 29 15:34:20 CST 2016 - dscudiero - sdfdfsdf
## Thu Dec 29 15:34:49 CST 2016 - dscudiero - x
## Thu Dec 29 15:35:00 CST 2016 - dscudiero - sddf
## Thu Dec 29 15:47:17 CST 2016 - dscudiero - testing
## Thu Dec 29 15:48:03 CST 2016 - dscudiero - eweerer
## Thu Dec 29 15:57:42 CST 2016 - dscudiero - Switch to use RunMySql
## Tue Jan  3 07:24:32 CST 2017 - dscudiero - fix problem creating employee table
## Wed Jan  4 07:24:06 CST 2017 - dscudiero - ake out debug statements, modify call to perfTest
## Wed Jan  4 16:47:34 CST 2017 - dscudiero - Updated BuildCourseleafData table to reflect the cgi versions including the patch level
## Thu Jan  5 07:59:27 CST 2017 - dscudiero - Fixed syntax error introduced on last commit
## Thu Jan  5 14:50:01 CST 2017 - dscudiero - Switch to use RunSql2
## Fri Jan  6 07:26:07 CST 2017 - dscudiero - Tweak messaging
## Tue Jan 10 12:54:12 CST 2017 - dscudiero - Add the -inPlace flag to the buildClientInfoTable call
## Wed Jan 11 07:00:53 CST 2017 - dscudiero - fix problem building skeleton shadow
## Wed Jan 11 07:04:10 CST 2017 - dscudiero - turn off db logging
## Wed Jan 11 09:09:57 CST 2017 - dscudiero - Add dailyshVer to UpdateCourseleafData
## Tue Jan 17 07:43:04 CST 2017 - dscudiero - cleanup
## Tue Jan 17 09:37:13 CST 2017 - dscudiero - removed the -inPlace option on the buildClientInfo table call
## Tue Jan 17 16:35:27 CST 2017 - dscudiero - Refactor logic arround build client & site tables
## Wed Jan 18 07:19:58 CST 2017 - dscudiero - Pass table name on the buildSiteInfoTable call
## Wed Jan 18 10:50:37 CST 2017 - dscudiero - Deleted 'backup' commented block, moved to local midnight file
## Thu Jan 19 15:32:02 CST 2017 - dscudiero - v
## Fri Jan 20 07:18:02 CST 2017 - dscudiero - fix issue with semaphores
## Thu Jan 26 07:29:17 CST 2017 - dscudiero - Tweaked logic for waiting for build clientx table to complete
## Thu Jan 26 10:49:31 CST 2017 - dscudiero - Update BuileEmployeeTable to reflect changes to the transactonal
## Thu Jan 26 12:14:25 CST 2017 - dscudiero - Moved the performance test as the first item run
## Fri Jan 27 07:56:33 CST 2017 - dscudiero - Switch how perftest is called
## Fri Jan 27 08:05:09 CST 2017 - dscudiero - Fix table swap for build employees table
## Fri Jan 27 14:31:19 CST 2017 - dscudiero - General syncing of dev to prod
## Tue Feb  7 07:54:13 CST 2017 - dscudiero - Fix loadCourseleafData function
## Tue Feb  7 08:22:12 CST 2017 - dscudiero - Add debug messages
## Wed Feb  8 10:57:32 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Feb 10 14:18:17 CST 2017 - dscudiero - Add debug code
## Fri Feb 10 16:12:53 CST 2017 - dscudiero - tweak the logic arround buildsiteinfotable
