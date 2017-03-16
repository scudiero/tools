#!/bin/bash
#DX NOT AUTOVERSION
#=======================================================================================================================
version=1.1.1 # -- dscudiero -- 03/16/2017 @ 15:44:21.39
#=======================================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye DumpMap GetExcel'
Import "$includes"
originalArgStr="$*"
scriptDescription="Build the qsStatus table by parsing the workbook files (*.xlsm) found in: $qaTrackingWorkbooks"

#= Description +===================================================================================
# Build the qsStatus table by parsing the workbook files (*.xlsm) found in: /steamboat/leepfrog/docs/QA
#=======================================================================================================================
#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
function parseArgs-buildQaStatusTable  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-buildQaStatusTable  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	[[ $savePath != '' ]] && export PATH="$savePath"
	return 0
}
function testMode-buildQaStatusTable  { # or testMode-local
	client='davetest'
	logInDb=false
	unset ignoreList
	return 0
}

#=======================================================================================================================
# local functions
#=======================================================================================================================

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

## Find the helper script location
	workerScript='insertTestingDetailRecord'; useLocal=true
	FindExecutable "$workerScript" 'full' 'Bash:sh' ## Sets variable executeFile
	workerScriptFile="$executeFile"

## Declare the mapping table from the spreadsheet 'name' and the database column name
	declare -A variableMap

	variableMap['Client Code']='clientCode'
	variableMap['Project']='project'
	variableMap['Jalot Task Number']='jalotTaskNumber'
	variableMap['Instance Name']='instance'
	variableMap['Environment']='env'
	variableMap['Requestor (CSM)']='requestor'
	variableMap['Tester']='tester'
	variableMap['Developer']='developer'
	variableMap['Front End Dev']='frontEndDeveloper'
	variableMap['Start Date']='startDate'
	variableMap['End Date']='endDate'
	variableMap['Estimated Effort (hours)']='resourcesEstimate'
	variableMap['Test Cases Defined']='numTests'
	variableMap['Attempted']='numAttempted'
	variableMap['Remaining']='numRemaining'
	variableMap['Passed']='numPassed'
	variableMap['Failed']='numFailed'
	variableMap['Waiting']='numBlocked'
	variableMap['Blocked']='numWaiting'
	variableMap['Other']='numOther'
	variableMap['Estimated Effort (hours)']='resourcesEstimate'
	variableMap['Effort to date (hours)']='resourcesUsed'
	variableMap['Effort Remaining (hours)']='resourcesRemaining'

## Get the primary index column name
	sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$qaStatusTable\"and column_key='PRI'"
	RunSql 'mysql' $sqlStmt
	primaryKey=${resultSet[0]}

## Get all the fields in the database table
	unset insertFields
	sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$qaStatusTable\" and column_name<>\"$primaryKey\""
	RunSql 'mysql' $sqlStmt
	for result in "${resultSet[@]}"; do
		field=$(cut -d'|' -f1 <<< $result)
		insertFields="$insertFields,$field"
	done
	insertFields=${insertFields:1}

## Get the update fields in the database table
	unset updateFields
	sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$qaStatusTable\" and is_nullable='yes' and column_name<>\"$primaryKey\""
	RunSql 'mysql' $sqlStmt
	for result in "${resultSet[@]}"; do
		field=$(cut -d'|' -f1 <<< $result)
		updateFields="$updateFields,$field"
	done
	updateFields=${updateFields:1}

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
helpSet='script,client,env'
scriptHelpDesc="$scriptDescription"

GetDefaultsData $myName
ParseArgsStd
Hello

myData="Client: '$client'"
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"
dump -2 -n client primaryKey -n insertFields -n updateFields
DumpMap 2 "$(declare -p variableMap)"

#================================================================================================================================================================
# Main
#================================================================================================================================================================
Msg2; Msg2 "QA Tracking Root directory = '$qaTrackingRoot'"
unset numTokens clientCode product project instance envName jalotTaskNumber
## Loop through workbooks
Msg2 "Scanning the directory..."
SetFileExpansion 'off'
[[ $client != "" ]] && fileSpec="$client-*.xlsm" || fileSpec='*.xlsm'
SetFileExpansion

SetFileExpansion 'on'
workbooks=($(ProtectedCall "ls $qaTrackingRoot/$fileSpec 2> /dev/null"))
#workbooks+=($(ProtectedCall "ls $qaTrackingRoot/Archive/$fileSpec 2> /dev/null"))
SetFileExpansion

for workbook in "${workbooks[@]}"; do
	fileName=$(basename $workbook)
	[[ ${fileName:0:1} == '~' ]] && continue
	[[ $(Contains "$workbook" 'old') == true || $(Contains "$workbook" 'bak') == true ]] && continue
	Msg2 $V1 "^Checking File: $workbook"
	## Get the list of worksheets in the workbook
		GetExcel "$workbook" 'GetSheets' > $tmpFile
		sheets=$(tail -n 1 $tmpFile)

	[[ $(Contains "|${sheets}|" '|ProjectSummary|') != true ]] && continue
	Msg2 "^Processing File: '$(basename $workbook)'"

	## Read the Project summary data
		workSheet='ProjectSummary'
		Msg2 $V1 "^^Parsing '$workSheet'..."
		GetExcel "$workbook" "$workSheet" > $tmpFile

	## Parse sheet data --  the variable names MUST match the data base column names
		unset $(tr ',' ' ' <<< $insertFields)
		foundFailed=false; foundWaiting=false;
		while read line; do
			dump -2 -n -t line
			[[ $(tr -d '|' <<< $line) == '' ]] && continue
			recType=$(Trim "$(cut -d'|' -f2 <<< $line)")
			[[ -z $recType ]] && continue
			dump -2 -t recType
			## Special processing for failed and waiting details records
				[[ $(Lower "$recType") == 'failed' ]] && foundFailed=true && foundWaiting=false
				[[ $(Lower "$recType") == 'waiting' ]] && foundWaiting=true && foundFailed=false
				[[ $(Lower "$recType") == 'dev' && $foundFailed == true ]] && numFailedDev="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue
				[[ $(Lower "$recType") == 'csm' && $foundFailed == true ]] && numFailedCSM="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue
				[[ $(Lower "$recType") == 'dev' && $foundWaiting == true ]] && numWaitingDev="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue
				[[ $(Lower "$recType") == 'csm' && $foundWaiting == true ]] && numWaitingCSM="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue

			## If 'instance' record  then parse off product and instance
				if [[ ${recType:0:8} == 'Instance' ]]; then
					product="$(cut -d'|' -f3 <<< $line | cut -d' ' -f1)"
					instance="$(cut -d'|' -f3 <<< $line | cut -d' ' -f3)"
					[[ $product == $instance ]] && unset instance
					continue
				fi

			## 'Standard' record, look up variable name in map
				if [[ ${variableMap["$recType"]+abc} ]]; then
					val="$(cut -d'|' -f3 <<< $line)"
					var=${variableMap[$recType]}
					[[ $(Contains "$var" 'Date') == true ]] && val="\"$(tr ' ' '@' <<< "$val")\""
					[[ ${var:0:3} == 'num' || $(Contains "$var" 'jalot') == true ]] && val="$(cut -d'.' -f1 <<< "$val")"
					dump -2 -t -t var val
					eval $var=\"$val\"
					dump -2 -t $var
				fi
		done < $tmpFile
		if [[ $verboseLevel -ge 2 ]]; then echo -e "\nFields:";for field in $(tr ',' ' ' <<< $insertFields); do echo -e "\t$field = ${!field}"; done; echo; fi

	## Do we have the data necessary to continue
		Msg2 $V1 "^^Checking data..."
		if [[ $clientCode == '' || $env == '' || $product == '' || $project == '' || $instance == '' || jalotTaskNumber == '' ]]; then
			Msg2 $WT1 "Insufficient data to uniquely identify QA project"
			dump -2 -t clientCode env product project instance jalotTaskNumber
			Msg2 "^^Skipping file"
			continue
		fi

	## Quote strings
		unset values
		for token in $(tr ',' ' ' <<< $insertFields); do
			#dump -n token $token
			if [[ "${!token}" != '' ]]; then
				tmpStr="\"${!token}\""
				eval $token=\'$tmpStr\'
			else
				eval $token='NULL'
			fi
		done

	## See if there is an existing record in the database do setup accordingly
		sqlStmt="select $primaryKey from $qaStatusTable where clientCode=$clientCode and env=$env and \
				product=$product and project=$project and instance=$instance and jalotTaskNumber=$jalotTaskNumber"
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -eq 0 ]]; then
			sqlAction='Insert'
			fields="$insertFields"
			createdBy="\"$userName\""
			createdOn="\"$(date +'%F %T')\""
			updatedBy='NULL'
			updatedOn='NULL'
			recordstatus="\"A\""
			unset whereClause
		else
			idx=${resultSet[0]}
			sqlAction='Update'
			fields="$updateFields"
			updatedBy="\"$userName\""
			updatedOn="\"$(date +'%F %T')\""
			whereClause="where idx=\"$idx\""
			recordstatus="\"A\""
		fi

	## Build sqlStmt 'set' clause
		unset setClause
		for token in $(tr ',' ' ' <<< $fields); do
			setClause="$setClause,${token}=${!token}"
		done
		setClause="Set $(tr '@' ' ' <<< "${setClause:1}")"
		dump -2 -n setClause -n

	## Build & run sqlStmt
		sqlStmt="$sqlAction $qaStatusTable $setClause $whereClause"
		RunSql 'mysql' $sqlStmt
		Msg2 $V1 "^^${sqlAction} of record completed"

	## Populate the testing detains table if workbook is finalized
		## Check to see if the workbook is finalized
		if [[ $(Contains "|${sheets}|" '|TestingDetailFinal|') == true ]]; then
			## Process the testing details records
			Msg2 "^^Processing Testing Details data via '$workerScript'..."
			ProtectedCall "Call "$workerScriptFile" "$workbook" 'TestingDetailFinal'"
			[[ $rc -ge 2 ]] && Msg2 $T "Processing the Testing Detail data, please review messages"
			if [[ $(Contains "$workbook" 'archive') == false ]]; then
				cwd=$(pwd)
				cd $(dirname $workbook)
				mv -f $workbook "$qaTrackingRoot/Archive/"
				cd $cwd
				## Get the key for the qastatus record
					whereClause="clientCode=\"$clientCode\" and  product=\"$product\" and project=\"$project\" and instance=\"$instance\" and env=\"$env\" and jalotTaskNumber=\"$jalotTaskNumber\" "
					sqlStmt="select idx from $qaStatusTable where $whereClause"
					RunSql $sqlStmt
					if [[ ${#resultSet[@]} -eq 0 ]]; then
						Error "Could not retrieve record key in $warehouseDb.$qaStatusTable for:\n^$whereClause\nCould not set the record as deactivated"
					else
						qastatusKey=${resultSet[0]}
						sqlStmt="update $qaStatusTable set recordStatus=\"D\" where idx=qastatusKey"
						RunSql $sqlStmt
					fi
			fi
		fi
done # Workbooks

#=======================================================================================================================
## Done
#=======================================================================================================================
Goodbye 0 #'alert'

#=======================================================================================================================
## Check-in log
#=======================================================================================================================
## Fri Aug  5 07:27:01 CDT 2016 - dscudiero - Script to build the Quality Assurance Status table
## Fri Aug  5 12:35:34 CDT 2016 - dscudiero - swith start and end dates to date format in the db
## Tue Aug 16 07:17:49 CDT 2016 - dscudiero - add ignoreList processing
## Thu Aug 25 12:54:48 CDT 2016 - dscudiero - Updated to match updates to the workbook
## Thu Aug 25 16:29:39 CDT 2016 - dscudiero - Refactored to update existing records vs always inserting new
## Wed Sep 14 10:25:22 CDT 2016 - dscudiero - Updated for new fields
## Wed Sep 14 15:15:23 CDT 2016 - dscudiero - Added logic to deactivate records
## Thu Oct  6 16:39:26 CDT 2016 - dscudiero - Set dbAcc level to Update for db writes
## Thu Oct  6 16:58:57 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 08:00:04 CDT 2016 - dscudiero - Take out the dbAcc switching logic, moved to framework RunSql
## Wed Oct 12 16:11:56 CDT 2016 - dscudiero - Incorporate building the testing details records
## Thu Oct 20 15:58:44 CDT 2016 - dscudiero - Make sure that the python environment is setup
## Mon Feb 20 12:52:53 CST 2017 - dscudiero - Adjustments for new spreadsheet
## Thu Mar 16 15:44:50 CDT 2017 - dscudiero - Added support for the 'blocked' data
