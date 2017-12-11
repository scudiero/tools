#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=1.22.50 # -- dscudiero -- Mon 12/11/2017 @ 10:18:57.72
#=======================================================================================================================
# Run nightly from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="RunCourseLeafCgi GetCourseleafPgm Semaphore FindExecutable ProtectedCall SetFileExpansion StringFunctions"
myIncludes="$myIncludes CalcElapsed"
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
	return 0
} #BuildEmployeeTable

#=======================================================================================================================
function BuildCourseleafDataTable {
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
			Msg3; Msg3 "Backing up database tables in $warehouseDb..."
			mySemaphoreId=$(Semaphore 'set' $myName)
			## Backup database tables
			for table in $clientInfoTable $siteInfoTable $siteAdminsTable $employeeTable ; do
				Msg3 "^$table..."
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
			Msg3 "...done"

		## If this is the first day of the month then truncate the sites table to reset the siteId counter
			if [[ $(date "+%d") = '01' ]]; then
				sqlStmt="truncate $siteInfoTable"
				RunSql2 $sqlStmt
			fi

		## Performance test
			## Make sure we have a sites table before running perfTest
			sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				pgmName="perfTest"
				Msg3 "\n$(date +"%m/%d@%H:%M") - Running $pgmName..."; sTime=$(date "+%s")
				TrapSigs 'off'; FindExecutable perfTest -sh -run; TrapSigs 'on'
				Msg3 "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			fi

		## Copy the contacts db from internal
			Msg3 "\nCopying contacts.sqlite files to $contactsSqliteFile..."
			cp $clientsTransactionalDb/contacts.sqlite $contactsSqliteFile
			touch $(dirname $contactsSqliteFile)/contacts.syncDate
			Msg3 "...done"

		## Scratch copy the skeleton shadow
			Msg3 "\nScratch copying the skeleton shadow..."
			chmod u+wx $skeletonRoot
			SetFileExpansion 'on'
			rm -rf $skeletonRoot/*
			rsyncOpts="-a --prune-empty-dirs"
			rsync $rsyncOpts /mnt/dev6/web/_skeleton/* $skeletonRoot | Indent
			SetFileExpansion
			touch $skeletonRoot/.syncDate
			Msg3 "^...done"

		## Run programs/functions
			pgms=(buildClientInfoTable buildSiteInfoTable BuildEmployeeTable buildQaStatusTable checkCgiPermissions checkPublishSettings)
			pgms+=(updateDefaults syncCourseleafGitRepos BuildCourseleafDataTable "cleanDev -daemon")
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg3 "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg3 "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done

		## Rebuild the internal site pages 
			Msg3 "\nRebuilding Internal pages"
			RunCourseLeafCgi "$stageInternal" "-r /clients"
			RunCourseLeafCgi "$stageInternal" "-r /support/tools"
			RunCourseLeafCgi "$stageInternal" "-r /support/qa"

		## Run Reports
			qaStatusShortEmails='sjones@leepfrog.com,mbruening@leepfrog.com,jlindeman@leepfrog.com'
			clientTimezoneEmails='dscudiero@leepfrog.com,jlindeman@leepfrog.com'
			reports=("qaStatusShort -email \"$qaStatusShortEmails\"" "clientTimezone -email \"$clientTimezoneEmails\"")
			for ((i=0; i<${#reports[@]}; i++)); do
				report="${reports[$i]}"; reportName="${report%% *}"; reportArgs="${report##* }"; [[ $reportName == $reportArgs ]] && unset reportArgs
				Msg3 "\n$(date +"%m/%d@%H:%M") - Running $reportName $reportArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'; FindExecutable scriptsAndReports -sh -run reports $report -quiet $reportArgs $scriptArgs | Indent; TrapSigs 'on'
				Semaphore 'waiton' "$reportName" 'true'
				Msg3 "...$reportName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done

		## On the last day of the month roll-up the log files
		  	if [[ $(date +"%d") == $(date -d "$(date +"%m")/1 + 1 month - 1 day" "+%d") ]]; then
		  		Msg3 "\n$(date +"%m/%d@%H:%M") - Rolling up monthly log files"; sTime=$(date "+%s")
				pushd $TOOLSPATH/Logs >& /dev/null
				SetFileExpansion 'on'
				tar -cvzf "$(date '+%b-%Y').tar.gz" $(date +"%m")-* --remove-files > /dev/null 2>&1
				SetFileExpansion
				popd  >& /dev/null
				Msg3 "... done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
		  	fi

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
				# else
				# 	sqlStmt="drop table if exists  ${table}Bak"
				# 	RunSql2 $sqlStmt
				fi
			done
			[[ $errorDetected == true ]] && Terminate 'One or more of the database load procedures failed, please review messages'

		 ## Create the data dump for the workwith tool
		 	Msg3 "^Building the 'WorkWith' client data file..."
			# # hostClause="(select distinct host from $siteInfoTable where $siteInfoTable.name=$clientInfoTable.name and $siteInfoTable.host <> 'N/A' \
			# # 			and $siteInfoTable.name not like '%-test') as host"
			# fields="$clientInfoTable.name,$clientInfoTable.longname,$clientInfoTable.hosting,$clientInfoTable.products,$siteInfoTable.host"
			# envsClause="GROUP_CONCAT(distinct env SEPARATOR ',') as envList"
			# serverClause="GROUP_CONCAT(distinct share SEPARATOR ',') as serverList"
			# fromClause="from $clientInfoTable,$siteInfoTable where ($siteInfoTable.name REGEXP $clientInfoTable.name) 
			# 			and $siteInfoTable.env not in('prior','public','preview')"
			# groupClause="GROUP BY $clientInfoTable.name"
		 # 	sqlStmt="select $fields,$serverClause,$envsClause,ifnull($siteInfoTable.cims,'') $fromClause $groupClause"
			# #echo; dump sqlStmt; echo
		 # 	RunSql2 $sqlStmt
		 # 	[[ ! -d $(dirname "$workwithDataFile") ]] && mkdir -p "$(dirname "$workwithDataFile")"
		 # 	echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE CLIENTS/SITES TABLES IN THE DATA WAREHOUSE" > "${workwithDataFile}.new"
			# for ((i=0; i<${#resultSet[@]}; i++)); do
			# 	echo "${resultSet[$i]}" >> "${workwithDataFile}.new"
			# done
			# [[ -f "$workwithDataFile" ]] && mv -f "${workwithDataFile}" "${workwithDataFile}.bak"
			# mv -f "${workwithDataFile}.new" "${workwithDataFile}"

		 	[[ ! -d $(dirname "$workwithDataFile") ]] && mkdir -p "$(dirname "$workwithDataFile")"
		 	echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE CLIENTS/SITES TABLES IN THE DATA WAREHOUSE" > "${workwithDataFile}.new"
			sqlStmt="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
		 	RunSql2 $sqlStmt
		 	ignoreList="${resultSet[$i]}"; ignoreList=${ignoreList##*:}; ignoreList="'${ignoreList//,/','}'"
			sqlStmt="select name,longName,hosting,products from $clientInfoTable where recordstatus=\"A\" and name not in ($ignoreList) order by name"
		 	RunSql2 $sqlStmt
			for rec in "${resultSet[@]}"; do clients+=("$rec"); done

			for ((i=0; i<${#clients[@]}; i++)); do
				clientRec="${clients[$i]}"
				client=${clientRec%%|*}
				unset envList
				sqlStmt="select env,cims from $siteInfoTable where name like \"$client%\""
		 		RunSql2 $sqlStmt
		 		if [[ ${#resultSet[@]} -gt 0 ]]; then
					for ((ii=0; ii<${#resultSet[@]}; ii++)); do
						envListStr="${resultSet[$ii]}"; envListStr=${envListStr//\|/:}
						envList="$envList;$envListStr"
					done
		 		fi
		 		clientRec="$clientRec|${envList:1}"
				echo "$clientRec" >> "${workwithDataFile}.new"
			done

			[[ -f "$workwithDataFile" ]] && mv -f "${workwithDataFile}" "${workwithDataFile}.bak"
			mv -f "${workwithDataFile}.new" "${workwithDataFile}"
			Msg3 "^...Done"

			## Refresh my local warehouse
			## [[ -x $HOME/bin/refreshDevWarehouse ]] && $HOME/bin/refreshDevWarehouse

		;; ## mojave

	*) ## build7
		## Wait until processing is release by the master process on mojave
			Msg3 "Waiting on '$myName'..."
			Semaphore 'waiton' "$myName"
			Msg3 "^'$myName' completed, continuing..."

		## Wait for the perftest process on mojave to complete
			## Make sure we have a sites table before running perfTest
			sqlStmt="SELECT table_name,create_time FROM information_schema.TABLES WHERE (TABLE_SCHEMA = \"$warehouseDb\") and table_name =\"$siteInfoTable\" "
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				Semaphore 'waiton' 'perftest'
				FindExecutable perfTest -sh -run
				FindExecutable perfTest -sh -run summary
			fi

		## Run programs/functions
			pgms=(buildSiteInfoTable checkCgiPermissions checkPublishSettings "cleanDev -daemon")
			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm##* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg3 "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg3 "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done
		;;
esac

#=======================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
Msg3 "\n$(date) -- $myName: Done\n"
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
