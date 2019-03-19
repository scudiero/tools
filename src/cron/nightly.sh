#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version="1.23.13" # -- dscudiero -- Tue 03/19/2019 @ 10:44:46
#=======================================================================================================================
# Run nightly from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="RunCourseLeafCgi GetCourseleafPgm Semaphore ProtectedCall StringFunctions CalcElapsed PushPop"
Import "$standardIncludes $myIncludes"

originalArgStr="$*";

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
function CleanToolsBin {
	Verbose -3 "*** $FUNCNAME -- Starting ***"

	## Setup lower case 'aliases' for the TOOLSPATH/bin commands, remove any links in bin that do not have a source in src
	Msg; Msg "Processing $TOOLSPATH/bin..."
	ignoreFiles=",scripts,reports,"
	cwd=$(pwd)
	cd $TOOLSPATH/bin
	files=$(find . -mindepth 1 -maxdepth 1 -type l -printf "%f ")
	for file in $files; do
		[[ $(Contains "$ignoreFiles" "$file") == true ]] && continue
		[[ ! -f $TOOLSPATH/src/${file}.sh && ! -f $TOOLSPATH/src/${file}.py && ! -f $TOOLSPATH/src/${file}.pl ]] && Warning "Removing: $file" && rm ../src/$file && continue
		[[ $file != $(Lower "$file") ]] && Msg "^Makeing link: $(Lower "$file")" && ln -s ./$file ./$(Lower "$file")
	done
	cd "$cwd"

	Verbose -3 "*** $FUNCNAME -- Completed ***"
	return 0
} #CleanToolsBin

#=======================================================================================================================
function CheckClientCount {
	Verbose -3 "*** $FUNCNAME -- Starting ***"
	## Get number of clients in transactional
	SetFileExpansion 'off'
	sqlStmt="select count(*) from clients where is_active=\"Y\""
	RunSql "$contactsSqliteFile" $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Terminate "Could not retrieve clients data from '$contactsSqliteFile'"
	else
		tCount=${resultSet[0]}
	fi
	## Get number of clients in warehouse
	sqlStmt="select count(*) from $clientInfoTable where recordstatus=\"A\""
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Terminate "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		wCount=${resultSet[0]}
	fi
	## Get number of clients on the ignore list
	sqlStmt="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Terminate "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		let numIgnore=$(grep -o "," <<< "${resultSet[0]}r" | wc -l)+1
		let tCount=$tCount-$numIgnore
	fi
	SetFileExpansion
	if [[ $tCount -gt $wCount ]]; then
		Msg "$FUNCNAME: New clients found in the transactional clients table, running 'clientList' report..."
		echo true
	else
		echo false
	fi
	return 0
} #CheckClientCount

#=======================================================================================================================
function BuildEmployeeTable {
	### Get the list of columns in the transactional employees table
		sqlStmt="pragma table_info(employees)"
		RunSql "$contactsSqliteFile" $sqlStmt
		unset transactionalFields transactionalColumns
		for resultRec in "${resultSet[@]}"; do
			transactionalColumns="$transactionalColumns,$(cut -d'|' -f2 <<< $resultRec)"
			transactionalFields="$transactionalFields,$(cut -d'|' -f2 <<< $resultRec)|$(cut -d'|' -f3 <<< $resultRec)"
		done
		transactionalColumns=${transactionalColumns:1}
		transactionalFields=${transactionalFields:1}

	### Clear out the employee table
			sqlStmt="truncate ${employeeTable}"
			RunSql $sqlStmt

	### Get the transactonal values, loop through them and  write out the warehouse record
		sqlStmt="select $transactionalColumns from employees order by db_employeekey"
		RunSql "$contactsSqliteFile" $sqlStmt
		for resultRec in "${resultSet[@]}"; do
			fieldCntr=1; unset valuesString userid
			for field in $(tr ',' ' ' <<< $transactionalFields); do
				column=$(cut -d'|' -f1 <<< $field)
				columnType=$(cut -d'|' -f2 <<< $field)
				eval "unset $column"
				eval "$column=\"$(cut -d '|' -f $fieldCntr <<< $resultRec)\""
				[[ $column == 'db_email' ]] &&{ eval "userid=\"${!column}\""; userid="${userid%%@*}"; }
				[[ $columnType == 'INTEGER' ]] && valuesString="$valuesString,${!column}" || valuesString="$valuesString,\"${!column}\""
				(( fieldCntr += 1 ))
			done
			valuesString="${valuesString:1},\"$userid\""
			sqlStmt="insert into ${employeeTable} values($valuesString)"
			RunSql $sqlStmt
		done
	return 0
} #BuildEmployeeTable

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
# GetDefaultsData $myName
# ParseArgsStd $originalArgStr
SetDefaults
ParseArgs $originalArgStr
scriptArgs="$* -noBanners"
logInDb=false

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
		## Processing that we want to completed before any cron tasks on other systems have started
			Msg; Msg "Backing up database tables in $warehouseDb..."
			mySemaphoreId=$(Semaphore 'set' $myName)
			## Backup database tables
			for table in $clientInfoTable $siteInfoTable $siteAdminsTable $employeeTable ; do
				Msg "^$table..."
				sqlStmt="drop table if exists ${table}Bak"
				RunSql $sqlStmt
				sqlStmt="create table ${table}Bak like ${table}"
				RunSql $sqlStmt
				SetFileExpansion 'off'
				sqlStmt="insert ${table}Bak select * from ${table}"
				RunSql $sqlStmt
				SetFileExpansion
			done
			echo
			Semaphore 'clear' $mySemaphoreId
			Msg "...done"

		## If this is Sunday then truncate the sites table to reset the siteId counter
			if [[ $(date "+%u") -eq 7 ]]; then
				sqlStmt="truncate $siteInfoTable"
				RunSql $sqlStmt
			fi

		## Performance test
			# ## Make sure we have a sites table before running perfTest
			# sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
			# RunSql $sqlStmt
			# if [[ ${#resultSet[@]} -gt 0 ]]; then
			# 	pgmName="perfTest"
			# 	Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName..."; sTime=$(date "+%s")
			# 	TrapSigs 'off'; FindExecutable perfTest -sh -run; TrapSigs 'on'
			# 	Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			# fi

		## Copy the contacts db from internal
			Msg "\nCopying contacts.sqlite files to $contactsSqliteFile..."
			cp $clientsTransactionalDb/contacts.sqlite $contactsSqliteFile
			touch $(dirname $contactsSqliteFile)/contacts.syncDate
			Msg "...done"

		## Run programs/functions
			pgms=(updateDefaults "cleanDev -daemon" "buildClientInfoTable" "buildSiteInfoTable" loadClientRoles)
			pgms+=(BuildEmployeeTable loadMilestonesData)
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done

		# ## Run courseleaf steps
		# 	internalUser="dscudiero"
		# 	internalPw="xxxxxxxxxx"
		# 	tmpFile1=$(mkTmpFile)
		# 	internalUrl="https://${internalUser}:${internalPw}@stage-internal.leepfrog.com/ribbit"
		# 	pgms=("getMilestones.rjs &output=check")
		# 	for ((i=0; i<${#pgms[@]}; i++)); do
		# 		pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
		# 		Msg "\n$(date +"%m/%d@%H:%M") - Running '$pgmName $pgmArgs'..."; sTime=$(date "+%s")
		# 		curl -s "$internalUrl/?page=${pgmName}${pgmArgs}" > "$tmpFile1"
		# 		# cat "$tmpFile1"
		# 		Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
		# 	done
		# 	rm -f "$tmpFile1"

		## Clean out dead entries from the 'auth' tables
			sqlStmt="delete from $auth2userTable where $auth2userTable.empKey not in (select employeeKey from $employeeTable where isactive = \"Y\")";
			RunSql $sqlStmt
			sqlStmt="delete from $auth2userTable where $auth2userTable.authKey not in (select groupId from $authGroupTable)"
			RunSql $sqlStmt
			sqlStmt="delete from $auth2scriptTable where $auth2scriptTable.scriptKey not in (select keyId from $scriptsTable)"
			RunSql $sqlStmt
			sqlStmt="delete from $auth2scriptTable where $auth2scriptTable.groupKey not in (select groupId from $authGroupTable)"
			RunSql $sqlStmt

		## Rebuild the internal site pages 
			Msg "\nRebuilding Internal pages..."
			RunCourseLeafCgi "$stageInternal" "-r /clients"
			RunCourseLeafCgi "$stageInternal" "-r /support/tools"
			RunCourseLeafCgi "$stageInternal" "-r /support/qa"

		## Run Reports
			# reports=("qaStatusShort -email \"${qaTeam}\"")
			# for ((i=0; i<${#reports[@]}; i++)); do
			# 	report="${reports[$i]}"; reportName="${report%% *}"; reportArgs="${report#* }"; [[ $reportName == $reportArgs ]] && unset reportArgs
			# 	Msg "\n$(date +"%m/%d@%H:%M") - Running $reportName $reportArgs..."; sTime=$(date "+%s")
			# 	TrapSigs 'off'; FindExecutable scriptsAndReports -sh -run reports $reportName $reportArgs $scriptArgs | Indent; TrapSigs 'on'
			# 	Semaphore 'waiton' "$reportName" 'true'
			# 	Msg "...$reportName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			# done

		## Check to see if we have received workflow specifications for any scheduled meetings
			let evenOdd=$(date +"%u")%2
			if [[ $evenOdd -eq 1 ]]; then ## On odd numbered days (Mon, Wed, Fri, Sun)
				Msg "\nChecking meetings.txt..."
				tmpFile=$(mkTmpFile)
				ifs="$IFS"; IFS=$'\r'; while read line; do
					[[ ${line:0:1} == '#' ]] && continue
					client="${line%% *}"; line="${line#* }"
					csm="${line%% *}"; line="${line#* }"
					date="${line%% *}"; line="${line#* }"

					# if [[ ! -d "$HOME/clientData/${client,,[a,z]}" ]]; then
						echo "*** Warning ***" > "$tmpFile"
						echo "A meeting, '$line', has been scheduled with $client on ${date}." >> "$tmpFile"
						echo "No workflow specifications have been received for this client so an audit and initial workflow has not been completed." >> "$tmpFile"
						echo "Specifications must be received at least 5 business days before the client meeting." >> "$tmpFile"
						echo "Should specifications not be provided, said meeting will be canceled on the Monday of the week that the meeting was scheduled" >> "$tmpFile"
						echo "" >> "$tmpFile"
						echo "Note: This is an automated emailing, no need to reply" >> "$tmpFile"
						mutt -s "Workflow meeting scheduled with $client without specs" -- ${csm}@leepfrog.com,dscudiero@leepfrog.com < $tmpFile;
					# fi
				done < "$HOME/clientData/meetings.txt"
			fi

		## On the last day of the month roll-up the log files
		  	if [[ $(date +"%d") == $(date -d "$(date +"%m")/1 + 1 month - 1 day" "+%d") ]]; then
		  		Msg "\nRolling up the log files..."
		  		Msg "\n$(date +"%m/%d@%H:%M") - Rolling up monthly log files"; sTime=$(date "+%s")
				pushd $TOOLSPATH/Logs >& /dev/null
				SetFileExpansion 'on'
				tar -cvzf "$(date '+%b-%Y').tar.gz" $(date +"%m")-* --remove-files > /dev/null 2>&1
				SetFileExpansion
				popd  >& /dev/null
				Msg "... done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
		  	fi

		## Process server move updates
			if [[ -r $TOOLSPATH/src/cron/serverMove.txt ]]; then
				Msg "\nProcessing server moves..."
				ifs="$IFS"; IFS=$'\r'; while read line; do
					[[ ${line:0:1} == '#' ]] && continue
					share="${line%% *}"; line="${line#* }"
					oldHost="${line%% *}"; line="${line#* }"
					newHost="$line"
					Msg "Processing server move update in '$siteInfoTable': '$share' --> '$newHost'"
					sqlStmt="update $siteInfoTable set host='$newHost' where share = '$share' and host='$oldHost'"
					RunSql $sqlStmt
				done < "$TOOLSPATH/src/cron/serverMove.txt"
				IFS="$ifs"
			fi

		 ## Check that all things ran properly, otherwise revert the databases
		 	Msg "\nCleanup..."
			Semaphore 'waiton' "buildClientInfoTable"
			Semaphore 'waiton' "buildSiteInfoTable"
			errorDetected=false
			for table in $clientInfoTable $siteInfoTable $siteAdminsTable $employeeTable; do
				sqlStmt="select count(*) from $table"
				RunSql $sqlStmt
				if [[ ${resultSet[0]} -eq 0 ]]; then
					Error "'$table' table is empty, reverting to original"
					errorDetected=true
					sqlStmt="drop table if exists ${table}"
					RunSql $sqlStmt
					sqlStmt="rename table ${table}Bak to ${table}"
					RunSql $sqlStmt
				# else
				# 	sqlStmt="drop table if exists  ${table}Bak"
				# 	RunSql $sqlStmt
				fi
			done
			[[ $errorDetected == true ]] && Terminate 'One or more of the database load procedures failed, please review messages'
			
		Msg "\nDone"

		## sync the jalot data warehouse tables
			Msg "\nSyncing the jalot data warehouse tables..."
			Pushd "/mnt/internal/site/stage/web/pagewiz"
			time ./pagewiz.cgi jalotWarhouseETL /
			Popd


		;; ## mojave

	*) ## build7
		## Wait until processing is release by the master process on mojave
			Msg "Waiting on '$myName'..."
			Semaphore 'waiton' "$myName"
			Msg "^'$myName' completed, continuing..."

		# ## Wait for the perftest process on mojave to complete
		# 	## Make sure we have a sites table before running perfTest
		# 	sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
		# 	RunSql $sqlStmt
		# 	if [[ ${#resultSet[@]} -gt 0 ]]; then
		# 		Semaphore 'waiton' 'perftest'
		# 		FindExecutable perfTest -sh -run
		# 		FindExecutable perfTest -sh -run summary
		# 	fi

		## Run programs/functions
			pgms=("buildSiteInfoTable" "cleanDev -daemon")
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
Msg "\n$(date) -- $myName: Done\n"
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
## Wed Jan  4 07:24:06 CST 2017 - dscudiero - Take out debug statements, modify call to perfTest
## Wed Jan  4 16:47:34 CST 2017 - dscudiero - Updated BuildCourseleafData table to reflect the cgi versions including the patch level
## Thu Jan  5 07:59:27 CST 2017 - dscudiero - Fixed syntax error introduced on last commit
## Thu Jan  5 14:50:01 CST 2017 - dscudiero - Switch to use RunSql
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
## 10-23-2017 @ 11.50.03 - (1.22.24)   - dscudiero - Uncommented the report calls
## 10-23-2017 @ 13.54.41 - (1.22.25)   - dscudiero - Cosmetic/minor change
## 10-26-2017 @ 07.42.51 - (1.22.30)   - dscudiero - Refactored how we call scripts
## 10-26-2017 @ 12.16.58 - (1.22.31)   - dscudiero - Tweak messaging
## 10-27-2017 @ 07.15.19 - (1.22.34)   - dscudiero - Misc cleanup
## 10-27-2017 @ 08.10.29 - (1.22.35)   - dscudiero - Use CalcElapsed function to calculate elapsed times
## 10-30-2017 @ 08.03.15 - (1.22.37)   - dscudiero - Truncate the sites table on the first of the month
## 11-01-2017 @ 07.58.07 - (1.22.39)   - dscudiero - Cosmetic/minor change
## 11-02-2017 @ 15.58.08 - (1.22.41)   - dscudiero - Temporarially remove buildQaStatusTable call
## 11-03-2017 @ 11.07.25 - (1.22.42)   - dscudiero - Add back buildQaStatusTable
## 11-21-2017 @ 08.16.49 - (1.22.43)   - dscudiero - Add call to refreshDevWarehouse to refresh local warehouse
## 11-28-2017 @ 14.33.20 - (1.22.44)   - dscudiero - Add the data dump for workwith
## 12-04-2017 @ 09.13.30 - (1.22.45)   - dscudiero - Update code building the workwith data file
## 12-06-2017 @ 11.16.18 - (1.22.46)   - dscudiero - Refactored building the defaults data files
## 12-07-2017 @ 10.08.34 - (1.22.47)   - dscudiero - Add a time stamp comment at the top of the workwith/clientdata file
## 12-08-2017 @ 07.34.33 - (1.22.48)   - dscudiero - COmment out refresh of dev data warehouse
## 12-08-2017 @ 09.27.37 - (1.22.49)   - dscudiero - fields="$clientInfoTable.name,$clientInfoTable.longname,$clientInfoTable.hosting,$clientInfoTable.products,$siteInfoTable.host"
## 12-08-2017 @ 09.27.56 - (1.22.49)   - dscudiero - Update sql query for workwith clientData to get all servers
## 12-11-2017 @ 11.47.05 - (1.22.50)   - dscudiero - Refactored the logic for how the workwith clientdata file is generated
## 12-11-2017 @ 13.26.50 - (1.22.51)   - dscudiero - Update workwith/clientdata logic again to add the server per env
## 12-11-2017 @ 16.19.46 - (1.22.56)   - dscudiero - tweak workWith/clientData again
## 12-12-2017 @ 06.58.07 - (1.22.57)   - dscudiero - removed debug statements from workwith.clientdata
## 12-12-2017 @ 09.22.22 - (1.22.58)   - dscudiero - Fix problem with select statement in workwith.data picking up too much data
## 12-12-2017 @ 09.49.11 - (1.22.59)   - dscudiero - Cosmetic/minor change
## 12-12-2017 @ 10.31.44 - (1.22.61)   - dscudiero - Cosmetic/minor change
## 03-09-2018 @ 14:25:41 - 1.22.62 - dscudiero - Add server move processing
## 03-22-2018 @ 12:47:03 - 1.22.64 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-22-2018 @ 14:36:09 - 1.22.65 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 12:09:15 - 1.22.66 - dscudiero - Comment out perfTest
## 03-23-2018 @ 15:34:02 - 1.22.68 - dscudiero - D
## 03-23-2018 @ 16:18:39 - 1.22.69 - dscudiero - D
## 03-26-2018 @ 08:47:13 - 1.22.71 - dscudiero - Fix problem calling reports
## 03-27-2018 @ 06:55:57 - 1.22.72 - dscudiero - Update call to clientByTimezone report
## 04-02-2018 @ 07:16:20 - 1.22.73 - dscudiero - Move timezone report to weekly
## 04-04-2018 @ 06:55:25 - 1.22.74 - dscudiero - Remove me from the qsShort report email
## 05-14-2018 @ 08:31:03 - 1.22.75 - dscudiero - Don't send reports to qaManager
## 05-14-2018 @ 09:53:21 - 1.22.76 - dscudiero - Comment out reports
## 06-06-2018 @ 07:05:43 - 1.22.76 - dscudiero - Remove the building of the skeleton shadow
## 06-11-2018 @ 16:50:52 - 1.22.77 - dscudiero - Added productsinsupport to the workwith data
## 06-13-2018 @ 10:27:06 - 1.22.78 - dscudiero - Remove NULL from the client record before being written out
## 06-14-2018 @ 07:14:14 - 1.22.78 - dscudiero - Go back to truncate
## 06-14-2018 @ 17:02:02 - 1.22.78 - dscudiero - Add loadAuthData to the list of programs to run on mojave
## 06-18-2018 @ 09:43:46 - 1.22.78 - dscudiero - Pull load workwith data code out and call the loadWorkwithData script
## 06-26-2018 @ 15:23:12 - 1.22.78 - dscudiero - Comment out code to update the courseleafDataTable
## 07-12-2018 @ 11:00:59 - 1.22.79 - dscudiero - Add checking of the master tool repo for commits
## 07-13-2018 @ 06:35:15 - 1.22.81 - dscudiero - Add messaging
## 09-10-2018 @ 16:00:15 - 1.22.82 - dscudiero - Change the order of programs, run updateData first
## 10-24-2018 @ 10:26:54 - 1.22.83 - dscudiero - Add call to loadMilestonesData
## 11-05-2018 @ 07:44:34 - 1.22.84 - dscudiero - Add call to buildClientRoles
## 11-05-2018 @ 09:25:12 - 1.22.85 - dscudiero - Fix bug setting useridl in buildEmployeeTable
## 11-05-2018 @ 10:27:08 - 1.22.86 - dscudiero - Remove loadAuthData
## 11-05-2018 @ 10:41:55 - 1.22.87 - dscudiero - Put back loading of workwith shadow data
## 11-07-2018 @ 09:23:12 - 1.22.88 - dscudiero - Update buildEmployeeTable to pull in all employee records,not just active
## 11-07-2018 @ 13:52:33 - 1.22.90 - dscudiero - Add auth table cleanup code
## 11-07-2018 @ 14:34:09 - 1.22.91 - dscudiero - Comment out building the workwith files
## 11-12-2018 @ 08:02:52 - 1.22.92 - dscudiero - Removed checks
## 12-11-2018 @ 11:19:03 - 1.22.93 - dscudiero - Fix syntax error in pushd statement
## 12-12-2018 @ 07:21:13 - 1.22.94 - dscudiero - Add verbose to build client and site tables
## 12-18-2018 @ 07:24:28 - 1.22.95 - dscudiero - Update setting of defaults to use the new toolsSetDefaults module
## 12-18-2018 @ 17:03:46 - 1.22.96 - dscudiero - Comment out debug statements
## 12-19-2018 @ 07:17:41 - 1.22.97 - dscudiero - Remove -v1 from the call to build site/clients table
## 01-25-2019 @ 13:03:27 - 1.22.98 - dscudiero - Remove dead code
## 01-31-2019 @ 10:10:31 - 1.22.99 - dscudiero - Moved git commit checkign to hourly
## 02-06-2019 @ 13:31:40 - 1.23.0 - dscudiero - Move workflow meeting messages to daily
## 02-07-2019 @ 07:45:09 - 1.23.1 - dscudiero - Tweak logic to determin when to run the meeting.txt code
## 02-08-2019 @ 09:08:29 - 1.23.2 - dscudiero - Truncate sites every sunday, remove misc debug statements
## 02-13-2019 @ 07:26:36 - 1.23.3 - dscudiero - Change meeting check to send out a single email with multiple addressee's
## 02-13-2019 @ 09:02:16 - 1.23.4 - dscudiero - Tweak messaging in sending meeting.txt emails
## 02-15-2019 @ 07:35:27 - 1.23.5 - dscudiero - Add messaging
## 02-18-2019 @ 08:22:28 - 1.23.7 - dscudiero - Add/Remove debug statements
## 02-22-2019 @ 07:34:25 - 1.23.8 - dscudiero - Add/Remove debug statements
## 02-25-2019 @ 07:44:54 - 1.23.9 - dscudiero - Add/Remove debug statements
## 03-05-2019 @ 15:22:08 - 1.23.11 - dscudiero - Comment out the courseleaf steps stuff
## 03-18-2019 @ 15:02:38 - 1.23.12 - dscudiero - Add jalot data warehouse table sync
## 03-19-2019 @ 10:45:14 - 1.23.13 - dscudiero - Tweak messaging
