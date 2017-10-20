#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=1.22.23 # -- dscudiero -- Fri 10/20/2017 @  8:05:02.15
#=======================================================================================================================
# Run nightly from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="RunCourseLeafCgi GetCourseleafPgm Semaphore FindExecutable ProtectedCall SetFileExpansion StringFunctions"
Import "$standardIncludes $myIncludes"
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
	Msg3 $V3 "*** $FUNCNAME -- Starting ***"

	## Setup lower case 'aliases' for the TOOLSPATH/bin commands, remove any links in bin that do not have a source in src
	Msg2; Msg3 "Processing $TOOLSPATH/bin..."
	ignoreFiles=",scripts,reports,"
	cwd=$(pwd)
	cd $TOOLSPATH/bin
	files=$(find . -mindepth 1 -maxdepth 1 -type l -printf "%f ")
	for file in $files; do
		[[ $(Contains "$ignoreFiles" "$file") == true ]] && continue
		[[ ! -f $TOOLSPATH/src/${file}.sh && ! -f $TOOLSPATH/src/${file}.py && ! -f $TOOLSPATH/src/${file}.pl ]] && Msg3 $WT1 "Removing: $file" && rm ../src/$file && continue
		[[ $file != $(Lower "$file") ]] && Msg3 "^Makeing link: $(Lower "$file")" && ln -s ./$file ./$(Lower "$file")
	done
	cd "$cwd"

	Msg3 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #CleanToolsBin

#=======================================================================================================================
function CheckClientCount {
	Msg3 $V3 "*** $FUNCNAME -- Starting ***"
	## Get number of clients in transactional
	SetFileExpansion 'off'
	sqlStmt="select count(*) from clients where is_active=\"Y\""
	RunSql2 "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg3 $T "Could not retrieve clients data from '$contactsSqliteFile'"
	else
		tCount=${resultSet[0]}
	fi
	## Get number of clients in warehouse
	sqlStmt="select count(*) from $clientInfoTable where recordstatus=\"A\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg3 $T "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		wCount=${resultSet[0]}
	fi
	## Get number of clients on the ignore list
	sqlStmt="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg3 $T "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		let numIgnore=$(grep -o "," <<< "${resultSet[0]}r" | wc -l)+1
		let tCount=$tCount-$numIgnore
	fi
	SetFileExpansion
	if [[ $tCount -gt $wCount ]]; then
		Msg3 "$FUNCNAME: New clients found in the transactional clients table, running 'clientList' report..."
		echo true
	else
		echo false
	fi
	return 0
} #CheckClientCount

#=======================================================================================================================
function BuildEmployeeTable {
	Msg3 "$FUNCNAME -- Starting"

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

	### Clear out the employee table
		sqlStmt="truncate ${employeeTable}"
		RunSql2 $sqlStmt

	### Get the transactonal values, loop through them and  write out the warehouse record
		sqlStmt="select $transactionalColumns from employees where db_isactive in (\"Y\",\"L\") order by db_employeekey"
		RunSql2 "$contactsSqliteFile" $sqlStmt
		for resultRec in "${resultSet[@]}"; do
			fieldCntr=1; unset valuesString userid
			for field in $(tr ',' ' ' <<< $transactionalFields); do
				column=$(cut -d'|' -f1 <<< $field)
				columnType=$(cut -d'|' -f2 <<< $field)
				eval "unset $column"
				eval "$column=\"$(cut -d '|' -f $fieldCntr <<< $resultRec)\""
				[[ ${column%%@leepfrog.com} != $column ]] && userid="${column%%@leepfrog.com}"
				[[ $columnType == 'INTEGER' ]] && valuesString="$valuesString,${!column}" || valuesString="$valuesString,\"${!column}\""
				(( fieldCntr += 1 ))
			done
			valuesString="${valuesString:1},userid=\"$userid\""
			sqlStmt="insert into ${employeeTable} values($valuesString)"
			RunSql2 $sqlStmt
		done

	Msg3 "$FUNCNAME -- Completed"
	return 0
} #BuildEmployeeTable

#=======================================================================================================================
function BuildCourseleafDataTable {
	Msg3 "$FUNCNAME -- Starting"

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

	Msg3 "$FUNCNAME -- Completed"
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
scriptArgs="$* -noBanners"
logInDb=false

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)

		## Processing that we want to completed before any cron tasks on other systems have started
			mySemaphoreId=$(Semaphore 'set' $myName)
			## Backup database tables
			echo
			for table in $clientInfoTable $siteInfoTable $siteAdminsTable $employeeTable ; do
				Msg3 "Backing up '$table'..."
				sqlStmt="drop table if exists ${table}Bak"
				RunSql2 $sqlStmt
				sqlStmt="create table ${table}Bak like ${table}"
				RunSql2 $sqlStmt
				SetFileExpansion 'off'
				sqlStmt="insert ${table}Bak select * from ${table}"
				RunSql2 $sqlStmt
				SetFileExpansion
			done
			echo
			Semaphore 'clear' $mySemaphoreId

		## Performance test
			Msg3 "Running perfTest..."
			FindExecutable perfTest -sh -run

		## Compare number of clients in the warehouse vs the transactional if more in transactional then runClientListReport=true
			#runClientListReport=$(CheckClientCount)

		## Copy the contacts db from internal
			Msg3 "Copying contacts.sqlite files to $contactsSqliteFile..."
			cp $clientsTransactionalDb/contacts.sqlite $contactsSqliteFile
			touch $(dirname $contactsSqliteFile)/contacts.syncDate
			Msg3 "^...done"

		## Build the clientInfoTable
			Msg3 "Running BuildClientInfoTable..."
			FindExecutable buildClientInfoTable -sh -run $scriptArgs | Indent
			Msg3 "Running BuildClientInfoTable) done"

		## Check to see of clients table has data
			sqlStmt="select count(*) from $clientInfoTable"
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				Error "Clients table is empty, skipping 'buildSiteInfoTable', semaphore kept in place"
			else
				## Build siteinfotabe and siteadmins table
				FindExecutable buildSiteInfoTable -sh -run $scriptArgs | Indent
			fi

		## Build employee table
			BuildEmployeeTable | Indent

		# ## Build the qaStatus table
		# 	FindExecutable buildQaStatusTable -sh -run $scriptArgs


		## Common Checks
			FindExecutable checkCgiPermissions -sh -run $scriptArgs
			FindExecutable checkPublishSettings -sh -run -fix $scriptArgs

		## Update the defaults data for this host
			FindExecutable updateDefaults -sh -run all $scriptArgs

		# ## Scratch copy the skeleton shadow
		# 	Msg3 "Scratch copying the skeleton shadow..."
		# 	chmod u+wx $skeletonRoot
		# 	SetFileExpansion 'on'
		# 	rm -rf $skeletonRoot/*
		# 	rsyncOpts="-a --prune-empty-dirs"
		# 	rsync $rsyncOpts /mnt/dev6/web/_skeleton/* $skeletonRoot
		# 	SetFileExpansion
		# 	touch $skeletonRoot/.syncDate
		# 	Msg3 "^...done"

		# ## Clean up the tools bin directory.
		# 	#CleanToolsBin

		## Sync GIT Shadow
			FindExecutable syncCourseleafGitRepos -sh -run $scriptArgs | Indent

		## Build the courseleafData table
			BuildCourseleafDataTable | Indent

		## Rebuild Internal pages to pickup any new database information
			## Wait for all of the buildSiteInfoTable process to finish
			Msg3 "\nWaiting on 'buildSiteInfoTable'..."
			Semaphore 'waiton' 'buildSiteInfoTable' 'true'
			Msg3 "^'buildSiteInfoTable' completed, continuing..."

			Msg3 "Rebuilding Internal pages"
			RunCourseLeafCgi "$stageInternal" "-r /clients"
			RunCourseLeafCgi "$stageInternal" "-r /support/tools"
			RunCourseLeafCgi "$stageInternal" "-r /support/qa"
			Msg3 "^buildClientInfoTable & buildSiteInfoTable Done"

		# ## Create a clone of the warehouse db
		# 	Msg3 "Creating '$warehouseDev' database..."
		# 	tmpConnectString=$(sed "s/Read/Admin/" <<< ${mySqlConnectString% *})

		# 	mysqldump $tmpConnectString $warehouseProd > /tmp/warehouse.sql;
		# 	mysql $tmpConnectString -e "drop database if exists $warehouseDev"
		# 	mysqladmin $tmpConnectString create $warehouseDev

		# 	mysql $tmpConnectString $warehouseDev < /tmp/warehouse.sql
		# 	[[ -f /tmp/warehouse.sql ]] && rm -f /tmp/warehouse.sql

		# ## Reports
		# 	qaEmails='sjones@leepfrog.com,mbruening@leepfrog.com,jlindeman@leepfrog.com'
		# 	FindExecutable qaStatusShort -sh -run reports -quiet -email \"$qaEmails\" $scriptArgs

		# 	## Build a list of clients and contact info for Shelia
		# 	#[[ $runClientListReport == true ]] && Call 'reports' "clientList -quiet -email 'dscudiero@leepfrog.com,sfrickson@leepfrog.com' $scriptArgs"

		# 	tzEmails='dscudiero@leepfrog.com,jlindeman@leepfrog.com'
		# 	[[ $(date +%d -d tomorrow) == '01' ]] && FindExecutable clientTimezone -sh -run reports -quiet -email \"$tzEmails\" $scriptArgs

		# ## On the last day of the month roll-up the log files
		#   	if [[ $(date +"%d") == $(date -d "$(date +"%m")/1 + 1 month - 1 day" "+%d") ]]; then
		#   		Msg3 "Rolling up monthly log files"
		# 		cd $TOOLSPATH/Logs
		# 		SetFileExpansion 'on'
		# 		tar -cvzf "$(date '+%b-%Y').tar.gz" $(date +"%m")-* --remove-files > /dev/null 2>&1
		# 		SetFileExpansion
		#   	fi

		 ## Check that all things ran properly, otherwise revert the databases
			Semaphore 'waiton' "buildClientInfoTable"
			Semaphore 'waiton' "buildSiteInfoTable"
			errorDetected=false
			for table in $clientInfoTable $siteInfoTable $siteAdminsTable $employeeTable; do
				sqlStmt="select count(*) from $table"
				RunSql2 $sqlStmt
				if [[ ${resultSet[0]} -eq 0 ]]; then
					Error "'$table' table is empty, reverting to original"
					errorDetected=true
					sqlStmt="drop table if exists ${table}"
					RunSql2 $sqlStmt
					sqlStmt="rename table ${table}Bak to ${table}"
					RunSql2 $sqlStmt
				fi
			done
			[[ $errorDetected == true ]] && Terminate 'One or more of the database load procedures failed, please review messages'

		## Remove private dev sites marked for auto deletion
			FindExecutable cleanDev -sh -run daemon $scriptArgs

		;; ## mojave

	*) ## build7
		## Wait until processing is release by the master process on mojave
			Msg3 "Waiting on '$myName'..."
			Semaphore 'waiton' "$myName"
			Msg3 "^'$myName' completed, continuing..."

		## Wait for the perftest process on mojave to complete
			Msg3 "Waiting on 'perftest'..."
			Semaphore 'waiton' 'perftest'
			Msg3 "^'perftest' completed, continuing..."
			FindExecutable perfTest -sh -run
			FindExecutable perfTest -sh -run summary

		## Build sites and siteadmins table
			FindExecutable buildSiteInfoTable -sh -run -table ${siteInfoTable} $scriptArgs

		## Common Checks
			FindExecutable checkCgiPermissions -sh-run -fix $scriptArgs
			FindExecutable checkPublishSettings -sh -run  $scriptArgs

		## Update the defaults data for this host
			FindExecutable updateDefaults -sh -run  $scriptArgs

		## Remove private dev sites marked for auto deletion
			FindExecutable cleanDev -sh -run -daemon $scriptArgs
		;;
esac

#=======================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
Msg3 "\n$myName: Done\n"
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
## Mon Feb 13 07:49:37 CST 2017 - dscudiero - Fix syntax problem
## Tue Feb 14 13:19:54 CST 2017 - dscudiero - Refactored control logic to sychronize processing amongst servers
## Tue Feb 14 14:06:43 CST 2017 - dscudiero - Add employeetable to the backup and recover list
## Wed Feb 15 07:17:19 CST 2017 - dscudiero - Fix problem naming databases for backup
## Wed Feb 15 10:31:00 CST 2017 - dscudiero - Added messageing
## Thu Feb 16 08:02:03 CST 2017 - dscudiero - Fix bug with buildEmployeeTable
## Fri Feb 17 06:59:08 CST 2017 - dscudiero - truncate the employee table before loading
## Mon Feb 20 08:00:56 CST 2017 - dscudiero - switch qaStatus report to qaStatusReportShort
## Thu Mar  9 07:50:47 CST 2017 - dscudiero - Take my userid out of the qa report email list
## Fri Mar 10 10:31:38 CST 2017 - dscudiero - added call to clientTimezone report
## Tue Mar 14 13:56:52 CDT 2017 - dscudiero - Change where the contacts db shadow is written
## Thu Mar 16 12:41:17 CDT 2017 - dscudiero - Update employee table to also get employees with status of L
## Thu Mar 16 12:45:54 CDT 2017 - dscudiero - General syncing of dev to prod
## 04-03-2017 @ 07.46.15 - (1.21.213)  - dscudiero - Take out call to buildWarhouseSqlite
## 04-03-2017 @ 07.53.15 - (1.21.215)  - dscudiero - add clientByTimezone report
## 04-04-2017 @ 09.41.52 - (1.21.216)  - dscudiero - added checkForPrivateDevSites
## 04-05-2017 @ 07.05.53 - (1.21.216)  - dscudiero - Take out checkForPrivateDevSites
## 04-06-2017 @ 10.09.59 - (1.21.217)  - dscudiero - renamed RunCourseLeafCgi, use new name
## 05-04-2017 @ 07.08.40 - (1.21.218)  - dscudiero - tweak order
## 05-04-2017 @ 14.20.54 - (1.21.219)  - dscudiero - Add call to cleanDevs
## 05-04-2017 @ 14.21.59 - (1.21.221)  - dscudiero - add cleanDevs call to build7
## 05-05-2017 @ 07.04.45 - (1.21.222)  - dscudiero - Fix call to cleanDev
## 05-09-2017 @ 08.01.30 - (1.21.223)  - dscudiero - fix call to cleanDev in build7 section
## 05-15-2017 @ 10.25.38 - (1.21.224)  - dscudiero - tweak message
## 05-19-2017 @ 07.27.02 - (1.22.0)    - dscudiero - update call string for quStatusShort report
## 05-22-2017 @ 07.28.45 - (1.22.0)    - dscudiero - Removed quiet from qaStatusReport call
## 05-23-2017 @ 07.56.21 - (1.22.1)    - dscudiero - Chang3e call string for reports
## 05-26-2017 @ 06.40.50 - (1.22.3)    - dscudiero - add quiet to qaStatusShort call
## 05-31-2017 @ 07.59.47 - (1.22.4)    - dscudiero - call scriptsAndReports directly for reports
## 08-30-2017 @ 12.45.12 - (1.22.5)    - dscudiero - move cleanDev to the en
## 09-06-2017 @ 07.20.12 - (1.22.6)    - dscudiero - add -fix to call to checkCgiPermissions
## 09-07-2017 @ 07.42.09 - (1.22.7)    - dscudiero - remove tablename from the buildsiteinfotable call
## 09-19-2017 @ 07.04.32 - (1.22.9)    - dscudiero - General syncing of dev to prod
## 09-28-2017 @ 08.49.49 - (1.22.10)   - dscudiero - Modify calls to updateDefaults to add mode
## 10-11-2017 @ 09.32.39 - (1.22.12)   - dscudiero - Add setting of userid in BuildEmployeeTable
## 10-11-2017 @ 10.37.40 - (1.22.14)   - dscudiero - Switch to use FindExecutable -run
## 10-17-2017 @ 16.54.01 - (1.22.16)   - dscudiero - Comment out stuff, only run core
## 10-18-2017 @ 13.48.43 - (1.22.18)   - dscudiero - Pipe output of run scripts through Indent
## 10-18-2017 @ 15.41.22 - (1.22.19)   - dscudiero - Change call string for cleanDevs to use -daemon switch
## 10-19-2017 @ 09.40.30 - (1.22.22)   - dscudiero - Switch -shortHello with -noBanners
## 10-20-2017 @ 08.20.40 - (1.22.23)   - dscudiero - s
