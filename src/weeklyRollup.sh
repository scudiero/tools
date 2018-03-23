#!/bin/bash
#DO NOT AUTPVERSION
#===================================================================================================
version=1.0.39 # -- dscudiero -- Fri 03/23/2018 @ 14:38:52.41
#===================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall RunSql SetFileExpansion"
Import "$standardIncludes $myIncludes"
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
#
#
#===================================================================================================
#===================================================================================================
# Standard call back functions
#===================================================================================================
function weeklyRollup-ParseArgsStd  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function weeklyRollup-Goodbye  { # or Goodbye-local
	return 0
}
function weeklyRollup-testMode  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Terminate "You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#===================================================================================================
# local functions
#===================================================================================================

#===================================================================================================
# Declare local variables and constants
#===================================================================================================
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#===================================================================================================
# Standard arg parsing and initialization
#===================================================================================================
Hello
GetDefaultsData $myName
ParseArgsStd $originalArgStr

#===================================================================================================
# Main
#===================================================================================================
## Update process counts
	Msg;Msg "^Update script usage counts -- Starting"
	## Get the aggregated processLog data and update counts in the scripts table.
	sql="select name,count(*) from $processLogTable group by name order by name"
	RunSql $sql
	pLogRecs=(${resultSet[*]})
	for pLogRec in ${pLogRecs[@]}; do
		pName=$(cut -d'|' -f1 <<< $pLogRec)
		pCount=$(cut -d'|' -f2 <<< $pLogRec)
		dump 1 -t pName pCount
		## Get the current count from the script record in the scripts table
			sql="select usageCount from scripts where name=\"$pName\""
			RunSql $sql
			usageCount=${resultSet[0]}
			dump 1 -t usageCount
		## Update usage count
			let newCount=$usageCount+$pCount
			dump 1 -t newCount
			sql="update $scriptsTable set usageCount=$newCount where name=\"$pName\""
			RunSql $sql
	done
	Msg "^Update script usage counts -- Completed"

## Roll up the weeks processlog db table
	Msg;Msg "^Processlog rollup -- Starting"
	cd $TOOLSPATH/Logs
	outFile="$(date '+%m-%d-%y').processLog.xls"
	## Get the column names
	sqlStmt="select column_name from information_schema.columns where table_schema = \"$warehouseDb\" and table_name = \"$processLogTable\""
	RunSql $sqlStmt
	resultString="${resultSet[@]}" ; resultString=$(tr " " "\t" <<< $resultString)
	echo "$resultString" >> $outFile
	SetFileExpansion 'off'
	sqlStmt="select * from $processLogTable"
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		for result in "${resultSet[@]}"; do
		 	resultString=$result; resultString=$(tr "|" "\t" <<< $resultString)
		 	echo "$resultString" >> $outFile
		done
		ProtectedCall "tar -cvzf \"$(date '+%m-%d-%y').processLog.tar\" $outFile --remove-files > /dev/null 2>&1"
	fi
	sqlStmt="truncate $processLogTable"
	RunSql $sqlStmt
	Msg "^Processlog rollup -- Completed"

## Roll up the weeks log files
	Msg;Msg "^Rollup weekly Logs -- Starting"
	cd $TOOLSPATH/Logs
	[[ -d ./cronJobs ]] && ProtectedCall "rm -rf ./cronJobs"
	ProtectedCall "tar -czf \"$(date '+%m-%d-%y').tar.gz\" * --exclude '*.gz' --exclude \"weekly*\"" #-remove-files
	ProtectedCall "find . -maxdepth 1 -mindepth 1 -type d -type d ! -name weekly -exec rm -rf {} \; > /dev/null 2>&1"
	Msg "^$myName Logs rollup -- Completed"

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Oct 10 07:11:50 CDT 2016 - dscudiero - Script to perform weekly log processing
## Fri Jan 13 07:53:53 CST 2017 - dscudiero - x
## Tue Jan 17 09:57:59 CST 2017 - dscudiero - Surround tar and find calls in a ProtectedCall
## Mon Feb 13 16:12:36 CST 2017 - dscudiero - make sure we have our own tmpFile
## 06-05-2017 @ 08.16.04 - (1.0.27)    - dscudiero - tweak messaging
## 09-21-2017 @ 10.03.00 - (1.0.28)    - dscudiero - comment out the truncating of the processlog
## 09-25-2017 @ 07.57.52 - (1.0.29)    - dscudiero - General syncing of dev to prod
## 10-23-2017 @ 08.30.56 - (1.0.32)    - dscudiero - Switch to Msg
## 11-22-2017 @ 06.25.55 - (1.0.33)    - dscudiero - Switch to ParseArgsStd
## 11-27-2017 @ 09.45.11 - (1.0.34)    - dscudiero - Fix problem deleting the weekly log file while in use
## 12-11-2017 @ 06.49.36 - (1.0.35)    - dscudiero - Update code excluding the weekly cron log
## 12-18-2017 @ 07.46.57 - (1.0.36)    - dscudiero - Fix problem with the final rollup deleteing the log directories
## 12-18-2017 @ 08.04.04 - (1.0.37)    - dscudiero - Cosmetic/minor change
## 03-22-2018 @ 14:07:55 - 1.0.38 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:36:23 - 1.0.39 - dscudiero - D
