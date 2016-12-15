#!/bin/bash
#DO NOT AUTPVERSION
#===================================================================================================
version=1.0.7 # -- dscudiero -- 12/14/2016 @ 11:31:50.59
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
#
#
#===================================================================================================
#===================================================================================================
# Standard call back functions
#===================================================================================================
function parseArgs-weeklyRollup  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-weeklyRollup  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-weeklyRollup  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Terminate "You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#===================================================================================================
# local functions
#===================================================================================================

#===================================================================================================
# Declare local variables and constants
#===================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#===================================================================================================
# Standard arg parsing and initialization
#===================================================================================================
GetDefaultsData $myName
ParseArgsStd

#===================================================================================================
# Main
#===================================================================================================
## Update process counts
	Msg2 "\n*** Update script usage counts -- Starting ***"
	## Get the aggregated processLog data and update counts in the scripts table.
	sql="select name,count(*) from $processLogTable group by name order by name"
	RunSql 'mySql' $sql
	pLogRecs=(${resultSet[*]})
	for pLogRec in ${pLogRecs[@]}; do
		pName=$(cut -d'|' -f1 <<< $pLogRec)
		pCount=$(cut -d'|' -f2 <<< $pLogRec)
		dump -t pName pCount
		## Get the current count from the script record in the scripts table
			sql="select usageCount from scripts where name=\"$pName\""
			RunSql 'mySql' $sql
			usageCount=${resultSet[0]}
			dump -t usageCount
		## Update usage count
			let newCount=$usageCount+$pCount
			dump -t newCount
			sql="update $scriptsTable set usageCount=$newCount where name=\"$pName\""
			RunSql 'mySql' $sql
	done
	Msg2 "\n*** Update script usage counts -- Completed ***"

## Roll up the weeks processlog db table
	Msg2 "\n*** Processlog rollup -- Starting ***"
	cd $TOOLSPATH/Logs
	outFile="$(date '+%m-%d-%y').processLog.xls"
	## Get the column names
	sqlStmt="select column_name from information_schema.columns where table_schema = \"$warehouseDb\" and table_name = \"$processLogTable\"";
	RunSql 'mysql' $sqlStmt
	resultString="${resultSet[@]}" ; resultString=$(tr " " "\t" <<< $resultString)
	echo "$resultString" >> $outFile
	SetFileExpansion 'off'
	sqlStmt="select * from $processLogTable"
	RunSql 'mysql' $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		for result in "${resultSet[@]}"; do
		 	resultString=$result; resultString=$(tr "|" "\t" <<< $resultString)
		 	echo "$resultString" >> $outFile
		done
		tar -cvzf "$(date '+%m-%d-%y').processLog.tar" $outFile --remove-files  #> /dev/null 2>&1
	fi
	sqlStmt="truncate $processLogTable"
	RunSql 'mySql' $sqlStmt
	SetFileExpansion
	Msg2 "\n*** Processlog rollup -- Completed ***"

## Roll up the weeks log files
	Msg2 "\n*** Rollup weekly Logs -- Starting ***"
	cd $TOOLSPATH/Logs
	[[ -d ./cronJobs ]] && rm -rf ./cronJobs
	tar -cvzf "$(date '+%m-%d-%y').tar.gz" * --exclude '*.gz' #--remove-files
	find . -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} \; > /dev/null 2>&1
	find . -maxdepth 1 -mindepth 1 -type f -name '*.tar' -exec rm -rf {} \; > /dev/null 2>&1
	Msg2 "\n*** Logs rollup -- Completed ***"


#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Oct 10 07:11:50 CDT 2016 - dscudiero - Script to perform weekly log processing
