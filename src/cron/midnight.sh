#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=1.21.144 # -- dscudiero -- 12/21/2016 @ 13:59:23.10
#=======================================================================================================================
# Run nightly from cron
#=======================================================================================================================
TrapSigs 'on'
Import FindExecutable GetDefaultsData ParseArgsStd ParseArgs RunSql Msg2 Call RunCoureleafCgi GetCourseleafPgm
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
	sql="select count(*) from clients where is_active=\"Y\""
	RunSql 'sqlite' "$contactsSqliteFile" $sql
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients data from '$contactsSqliteFile'"
	else
		tCount=${resultSet[0]}
	fi
dump tCount
	## Get number of clients in warehouse
	sql="select count(*) from $clientInfoTable where recordstatus=\"A\""
	RunSql 'mysql' $sql
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		wCount=${resultSet[0]}
	fi
dump wCount
	## Get number of clients on the ignore list
	sql="select ignoreList from $scriptsTable where name=\"buildClientInfoTable\""
	RunSql 'mysql' $sql
	if [[ ${#resultSet[@]} -le 0 ]]; then
		Msg2 $T "Could not retrieve clients count data from '$warehouseDb.$clientInfoTable'"
	else
		let numIgnore=$(grep -o "," <<< "${resultSet[0]}r" | wc -l)+1
		let tCount=$tCount-$numIgnore
	fi
dump numIgnore tcount
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
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"
	sqlStmt="truncate $employeeTable"
	RunSql 'mySql' $sqlStmt
	### Get the list of columns in the transactional employees table
	sqlStmt="pragma table_info(employees)"
	RunSql 'sqlite' "$contactsSqliteFile" $sqlStmt
	unset transactionalFields transactionalColumns
	for resultRec in "${resultSet[@]}"; do
		transactionalColumns="$transactionalColumns,$(cut -d'|' -f2 <<< $resultRec)"
		transactionalFields="$transactionalFields,$(cut -d'|' -f2 <<< $resultRec)|$(cut -d'|' -f3 <<< $resultRec)"
	done
	transactionalColumns=${transactionalColumns:1}
	transactionalFields=${transactionalFields:1}

	### Get the list of columns in the warehouse employee table
	#sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$employeeTable\";"
	#RunSql 'mysql' $sqlStmt
	#for resultRec in "${resultSet[@]}"; do
	#	warehouseFields="$transactionalFields,$resultRec"
	#done
	#warehouseFields=${warehouseFields:1}

	### Get the transactonal values, loop through them and  write out the warehouse record
	sqlStmt="select $transactionalColumns from employees where db_isactive = \"Y\" order  by db_employeekey"
	RunSql 'sqlite' "$contactsSqliteFile" $sqlStmt
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
		sqlStmt="insert into $employeeTable values($valuesString)"
		RunSql 'mySql' $sqlStmt
	done

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
	return 0
} #BuildEmployeeTable

#=======================================================================================================================
function BuildCourseleafDataTable {
	Msg2 $V3 "*** $FUNCNAME -- Starting ***"

	## Clean out the existing data
	sql="truncate $courseleafDataTable"
	RunSql 'MySql' $sql

	## Get Courseleaf component versions
		components=($(find $gitRepoShadow -maxdepth 1 -mindepth 1 -type d -printf "%f "))
		for component in "${components[@]}"; do
			dirs=($(ls -c $gitRepoShadow/$component | ProtectedCall "grep -v master"))
			[[ ${#dirs[@]} -gt 0 ]] && latest=${dirs[0]} || latest='master'
			sql="insert into $courseleafDataTable values(NULL,\"$component\",NULL,\"$latest\",NOW(),\"$userName\")"
			RunSql 'MySql' $sql
		done

	## Get Courseleaf cgi versions
		cwd=$(pwd)
		cd $cgisRoot
		for rhelDir in $(ls | grep '^rhel[0-9]$'); do
			dirs=($(ls -c ./$rhelDir | ProtectedCall "grep -v prev_ver"))
			[[ ${#dirs[@]} -gt 0 ]] && latest=${dirs[0]} || latest='master'
			sql="insert into $courseleafDataTable values(NULL,\"courseleaf.cgi\",\"$rhelDir\",\"$latest\",NOW(),\"$userName\")"
			RunSql 'MySql' $sql
		done

	## Rebuild the page
		cwd=$(pwd)
		cd /mnt/internal/site/stage/web/pagewiz
		./pagewiz.cgi -r /support/courseleafData
		cd $cwd

	Msg2 $V3 "*** $FUNCNAME -- Completed ***"
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

#=======================================================================================================================
# Main
#=======================================================================================================================
case "$hostName" in
	mojave)
			## Set a semaphore
				sqlStmt="truncate $semaphoreInfoTable"
				RunSql 'mysql' $sqlStmt
				sqlStmt="insert into $semaphoreInfoTable values(NULL,\"$myName\",NULL,NULL,NULL)"
				RunSql 'mySql' $sqlStmt

				## Compare number of clients in the warehouse vs the transactional if more in transactional then runClientListReport=true
					runClientListReport=$(CheckClientCount)
dump runClientListReport

				## Copy the contacts db from internal
					Msg2 "Copying contacts.sqlite files to $sqliteDbs/contacts.sqlite..."
					cd $clientsTransactionalDb
					cp $clientsTransactionalDb/contacts.sqlite $sqliteDbs/contacts.sqlite
					touch $sqliteDbs/contacts.syncDate
					Msg2 "^...done"

				## Truncate the tables
					sqlStmt="truncate $clientInfoTable"
					RunSql 'mysql' $sqlStmt
					sqlStmt="truncate $siteInfoTable"
					RunSql 'mysql' $sqlStmt
					sqlStmt="truncate $siteAdminsTable"
					RunSql 'mysql' $sqlStmt

				## Build the clientInfoTable
					Call 'buildClientInfoTable' "$scriptArgs"

			## Clear a semaphore
				sqlStmt="delete from $semaphoreInfoTable where processName=\"$myName\""
				RunSql 'mySql' $sqlStmt

			## Build siteinfotabe and siteadmins table
				Call 'buildSiteInfoTable' "$scriptArgs"

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
				chmod u+wx $TOOLSPATH/courseleafSkeletonShadow
				SetFileExpansion 'on'
				rm -rf $TOOLSPATH/courseleafSkeletonShadow/*
				rsyncOpts="-a --prune-empty-dirs"
				rsync $rsyncOpts /mnt/dev6/web/_skeleton/* $TOOLSPATH/courseleafSkeletonShadow
				SetFileExpansion
				touch $TOOLSPATH/courseleafSkeletonShadow/.syncDate
				Msg2 "^...done"

			## Build a sqlite clone of the data warehouse
				Call 'buildWarehouseSqlite' "$scriptArgs"

			# ## Backup files
			# 		mySqlConnectStringSave="$mySqlConnectString"
			# 		mySqlConnectString=$(sed "s/Read/Admin/" <<< $mySqlConnectString)
			# 	## Dump the production data warehouse database
			# 		mysqldump $mySqlConnectString > /tmp/warehouse.sql
			# 	## Dump the production contacts database
			# 		sqlStmt=".dump"
			# 		sqlite3 "$contactsSqliteFile" "$sqlStmt" > /tmp/contacts.sql
			# 	## Create a clone of the warehouse db
			# 		Msg2
			# 		mysql $mySqlConnectString -e "drop database if exists $warehouseDev"
			# 		mysqladmin ${mySqlConnectString% *} create $warehouseDev
			# 		mysql ${mySqlConnectString% *} $warehouseDev < /tmp/warehouse.sql
			# 	## Cleanup
			# 		[[ -f /tmp/warehouse.sql ]] && rm -f /tmp/warehouse.sql
			# 		[[ -f /tmp/contacts.sql ]] && rm -f /tmp/contacts.sql

			## Clean up the tools bin directory.
				#CleanToolsBin

			## Sync GIT Shadow
				Call 'syncCourseleafGitRepos' "$scriptArgs"

			## Create a clone of the warehouse db
				Msg2 "Creating $warehouseDev database..."
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

			## Performance test
				perfTest

			;;
	*) ## build5 and build7
			sleep 30 ## Wait for process to start on mojave
			## Check semaphore, wait for truncate to be done on mojave
				sqlStmt="select count(*) from $semaphoreInfoTable where processName=\"$myName\""
				while true; do
					RunSql 'mySql' $sqlStmt
					[[ ${resultSet[@]} -eq 0 ]] && break
					sleep 30
				done

			## Build siteinfotabe and siteadmins table
				Call 'buildSiteInfoTable' "$scriptArgs"
			## Common Checks
				Call 'checkCgiPermissions' "$scriptArgs"
			## Update the defaults data for this host
				Call 'updateDefaults' "$scriptArgs"
			;;
esac

#=======================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
return 0

#=======================================================================================================================
# Change Log
#=======================================================================================================================
