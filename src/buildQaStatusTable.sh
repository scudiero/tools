#!/bin/bash
#DX NOT AUTOVERSION
#=======================================================================================================================
version=1.2.52 # -- dscudiero -- Tue 10/31/2017 @ 10:51:38.90
#=======================================================================================================================
TrapSigs 'on'

myIncludes="GetExcel2 StringFunctions RunSql2 SetFileExpansion ProtectedCall PushPop"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Build the '$qaStatusTable' table by parsing the workbook files (*.xlsm) found in: $qaTrackingWorkbooks"

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
	cimTrackingWorkBook="$HOME/CIM - Multiweek - INTERNAL.xlsx"
	logInDb=false
	return 0
}

#=======================================================================================================================
# local functions
#=======================================================================================================================
#=======================================================================================================================
# Read the CIM tacking workbook and retrieve the data for the QA person
# Usage:
# GetCimPriorityData <outputHashName> <workBook> <workSheet> <QAperson>
# Returns:
#	'priorityWeek'	= The date from the priority spreadsheet
#	'<outputHashName>'	= Hash table, the key is in the form 'client-instanceAdmin-project-env'
#						 Value of the has is the allocated hours for the project tasks
#
#=======================================================================================================================
	function GetCimPriorityData {
		local outHashName="$1"; shift
		local workBook="$1"; shift
		local workSheet="$1"; shift
		local findColText="$(Lower "$1")"; shift
		local grepStr line lines found=false IFSave="$IFS" fieldCntr=0 sheetCol sheetCols itemCol
		local itemHrsCol item itemHrs priority=1 ctClient ctInstance ctProject hashKey mapCtr
		dump -2 product workBook workSheet findColText

		## Read the Worksheet data
			GetExcel2 -wb "$workBook" -ws "$workSheet"
			[[ ${#resultSet[@]} -le 0 ]] && Terminate "$FUNCNAME: Could not retrieve data from workbook\n$workBook / $workSheet"

		# Parse the header record, getting the column numbers of the fields
			[[ $(Contains "$(Lower "${resultSet[0]}")" "$findColText") != true ]] && Terminate "$FUNCNAME: First record:\n\t'${resultSet[0]}'\nof the worksheet did not contain '$findColText'"
			IFSave=$IFS; IFS=\|; sheetCols=(${lines[0]}); IFS=$IFSave;
			for sheetCol in "${sheetCols[@]}"; do
				(( fieldCntr += 1 ))
				[[ $(Lower "$(Trim "$sheetCol")") == "$findColText" ]] && found=true && break
			done
			[[ $found != true ]] && Terminate "$FUNCNAME: Could not locate a column with name '$findColText' in the Worksheet"
			itemCol=$fieldCntr
			itemHrsCol=$((itemCol+1))
			dump -2 itemCol itemHrsCol

		## Loop throug spreadsheet records getting data
			priorityWeek=$(cut -d'|' -f $itemCol <<< ${resultSet[1]})
			priorityWeek=${priorityWeek##* }
			dump -2 priorityWeek
			for ((jj=2; jj<${#resultSet[@]}; jj++)); do
				item="$(Lower "$(cut -d'|' -f $itemCol <<< ${resultSet[$jj]})")"
				itemHrs="$(cut -d'|' -f $itemHrsCol <<< ${resultSet[$jj]})"
				[[ -z ${item}${itemHrs} ]] && continue
				[[ $item == 'meetings (hrs)' ]] && break
				ctClient="$(cut -f1 -d' ' <<< "$item")"
				ctInstance="$(cut -f2 -d' ' <<< "$item")"
				ctProject="$(cut -f3 -d' ' <<< "$item")"
				[[ -z $ctProject ]] && ctProject='Implementation'
				if [[ $ctProject == 'mn' || $(Contains "$(Lower "$item")" 'next') == true ]]; then
					ctProject='Implementation'
					ctEnv='mn'
				else
					ctEnv="$(cut -f4 -d' ' <<< "$item")"
				fi
				[[ $ctEnv == 'mn' ]] && ctEnv='next' || ctEnv='test'
				hashKey="$(Lower "$ctClient-$(TitleCase "$ctInstance")Admin-$ctProject-$ctEnv")"
				dump -2 -n item itemHrs -t hashKey
				cimTrackingHash[$hashKey]="$itemHrs"
				eval "$outHashName[$hashKey]=\"$itemHrs|$priority\""
				((priority+=1))
			done

			[[ -f $tmpFile ]] && rm -f $tmpFile
			[[ -f $tmpFile.2 ]] && rm -f $tmpFile.2

		return 0
	} ##GetCimPriorityData

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
tmpFile=$(mkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

## source data and hash tables
	declare -A cimTrackingHash
	declare -A catTrackingHash
	cimTrackingWorkBook="$cimTrackingDir/CIM - Multiweek - INTERNAL.xlsx"
	cimTrackingWorkbookSheet='ThisWeekinCIM'
	cimTester='Scotta'

## Find the helper script location
	workerScript='insertTestingDetailRecord'
	workerScriptFile="$(FindExecutable "$workerScript")"
	[[ -z $workerScriptFile ]] && Terminate "Could find the workerScriptFile file ('$workerScript')"

## Declare the mapping table from the spreadsheet 'name' and the database column name
	declare -A variableMap

	variableMap['Client Code']='clientCode'
	variableMap['Project']='project'
	#variableMap['Jalot Task Number']='jalotTaskNumber'
	variableMap['Instance Name']='instance'
	variableMap['Environment']='env'
	variableMap['Requester (CSM)']='requester'
	variableMap['Requestor (CSM)']='requester'
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
	variableMap['Waiting']='numWaiting'
	variableMap['Blocked']='numBlocked'
	variableMap['Other']='numOther'
	variableMap['Estimated Effort (hours)']='resourcesEstimate'
	variableMap['Effort to date (hours)']='resourcesUsed'
	variableMap['Effort Remaining (hours)']='resourcesRemaining'

## Get the primary index column name
	sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$qaStatusTable\"and column_key='PRI'"
	RunSql2 $sqlStmt
	primaryKey=${resultSet[0]}

## Get all the fields in the database table
	unset insertFields
	sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$qaStatusTable\" and column_name<>\"$primaryKey\""
	RunSql2 $sqlStmt
	for result in "${resultSet[@]}"; do
		field=$(cut -d'|' -f1 <<< $result)
		insertFields="$insertFields,$field"
	done
	insertFields=${insertFields:1}

## Get the update fields in the database table
	unset updateFields
	sqlStmt="select column_name from information_schema.columns where table_schema=\"$warehouseDb\" and table_name=\"$qaStatusTable\" and is_nullable='yes' and column_name<>\"$primaryKey\""
	RunSql2 $sqlStmt
	for result in "${resultSet[@]}"; do
		field=$(cut -d'|' -f1 <<< $result)
		updateFields="$updateFields,$field"
	done
	updateFields=${updateFields:1}

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
helpSet='script,client,env'

GetDefaultsData $myName
ParseArgsStd
Hello
[[ $batchMode != true ]] && VerifyContinue "You are asking to re-generate the data warehouse '$qaStatusTable' table"

myData="Client: '$client'"
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"
dump -2 -n client primaryKey -n insertFields -n updateFields
DumpMap 2 "$(declare -p variableMap)"

#================================================================================================================================================================
# Main
#================================================================================================================================================================
Msg3; Msg3 "Retrieveing Implementation Team data from '$(basename "$cimTrackingWorkBook")/$cimTrackingWorkbookSheet'"
GetCimPriorityData 'cimTrackingHash' "$cimTrackingWorkBook" "$cimTrackingWorkbookSheet" "$cimTester"
if [[ $verboseLevel -ge 1 ]]; then
	dump -t priorityWeek
	echo -e "\tcimTrackingHash:"
	for mapCtr in "${!cimTrackingHash[@]}"; do
		echo -e "\t\tkey: '$mapCtr', value: '${cimTrackingHash[$mapCtr]}'";
	done;
fi

Msg3; Msg3 "QA Tracking Root directory = '$qaTrackingRoot'"
unset numTokens clientCode product project instance
## Loop through workbooks
Msg3 "Scanning the directory..."
SetFileExpansion 'off'
[[ $client != "" ]] && fileSpec="$client-*.xlsm" || fileSpec='*.xlsm'
SetFileExpansion

SetFileExpansion 'on'
workbooks=($(ProtectedCall "ls $qaTrackingRoot/$fileSpec 2> /dev/null"))
#workbooks+=($(ProtectedCall "ls $qaTrackingRoot/Archive/$fileSpec 2> /dev/null"))
SetFileExpansion

fileCntr=1
for workbook in "${workbooks[@]}"; do
	fileName=$(basename $workbook)
	[[ ${fileName:0:1} == '~' ]] && continue
	[[ $(Contains "$workbook" 'old') == true || $(Contains "$workbook" 'bak') == true ]] && continue
	Msg3 $V1 "^Checking File: $workbook"
	## Get the list of worksheets in the workbook
		GetExcel2 -wb "$workbook" -ws 'GetSheets'
		sheets="${resultSet[0]}"

	[[ $(Contains "|${sheets}|" '|ProjectSummary|') != true ]] && continue
	Msg3 "^Processing File: '$(basename $workbook)' ($fileCntr of ${#workbooks[@]})"

	## Read the Project summary data
		workSheet='ProjectSummary'
		Msg3 $V1 "^^Parsing '$workSheet'..."
		GetExcel2 -wb "$workbook" -ws "$workSheet"

	## Parse sheet data --  the variable names MUST match the data base column names
		unset $(tr ',' ' ' <<< $insertFields)
		foundFailed=false; foundWaiting=false; foundNotes=false

		for ((i=0; i<${#resultSet[@]}; i++)); do
			line="${resultSet[$i]}"
			dump -2 -n -t line
			[[ $(tr -d '|' <<< $line) == '' ]] && continue
			recType=$(Trim "$(cut -d'|' -f2 <<< $line)")
			[[ -z $recType ]] && continue
			dump -2 -t recType
			recTypeLower=$(Lower "$recType")

			## Is this the title record, parse of sheet version
				if [[ $recTypeLower == 'projectsummary' ]]; then
					sheetVersion=${line##*|}
					token1=$(cut -d'.' -f1 <<< $sheetVersion); token1=${token1}00; token1=${token1:0:3}
					token2=$(cut -d'.' -f2 <<< $sheetVersion); token2=${token2}00; token2=${token2:0:3}
					token3=$(cut -d'.' -f3 <<< $sheetVersion); token3=00${token3}; token3=${token3: -3}
					sheetVersion="${token1}${token2}${token3}"
				fi

			## Special processing for failed and waiting details records
				[[ $recTypeLower == 'failed' ]] && foundFailed=true && foundWaiting=false
				[[ $recTypeLower == 'waiting' ]] && foundWaiting=true && foundFailed=false
				[[ $recTypeLower == 'dev' && $foundFailed == true ]] && numFailedDev="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue
				[[ $recTypeLower == 'csm' && $foundFailed == true ]] && numFailedCSM="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue
				[[ $recTypeLower == 'dev' && $foundWaiting == true ]] && numWaitingDev="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue
				[[ $recTypeLower == 'csm' && $foundWaiting == true ]] && numWaitingCSM="$(cut -d'|' -f3 <<< $line | cut -d'.' -f1)" && continue

			## Special processing for failed and waiting details records
				[[ $recTypeLower == 'notes:' ]] && foundNotes=true && continue
				[[ $foundNotes == true ]] && notes="$(cut -d'|' -f2 <<< $line)" && dump -2 -t notes && foundNotes=false && continue

			## If 'instance' record  then parse off product and instance
				if [[ ${recTypeLower:0:8} == 'instance' ]]; then
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
					[[ $(Contains "$var" 'resources') == true ]] && val=$(printf "%.2f" $val)
					dump -2 -t -t var val
					eval $var=\"$val\"
					dump -2 -t $var
				fi
		done
		if [[ $verboseLevel -ge 2 ]]; then echo -e "\nFields:";for field in $(tr ',' ' ' <<< $insertFields); do echo -e "\t$field = ${!field}"; done; echo; fi

	## Do we have the data necessary to continue
		Msg3 $V1 "^^Checking data..."
		if [[ $clientCode == '' || $env == '' || $product == '' || $project == '' || $instance == '' ]]; then
			Msg3 $WT1 "File '$workbook'\nhas insufficient data to uniquely identify QA project"
			dump -t -t clientCode env product project instance
			Msg3 "^^Skipping file"
			continue
		fi

	## Do we have data for this record from the implimentaiton team tracking spreadsheet
		checkKey="$(Lower "$clientCode-$instance-$project-$env")"
		if [[ ${cimTrackingHash[$checkKey]+abc} ]]; then
			implPriorityWeek="$priorityWeek"
			tmpVal="${cimTrackingHash["$checkKey"]}"
			implHours="${tmpVal%%|*}"
			implPriority="${tmpVal##*|}"
		else
			unset implPriorityWeek implHours implPriority
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
		whereClause="clientCode=$clientCode and env=$env and product=$product and project=$project and instance=$instance"
		sqlStmt="select $primaryKey from $qaStatusTable where $whereClause and recordStatus=\"A\""
		RunSql2 $sqlStmt
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
		dump -2 -n sqlAction fields whereClause

	## Build sqlStmt 'set' clause
		unset setClause
		for token in $(tr ',' ' ' <<< $fields); do
			[[ $token == 'jalot' ]] && continue
			setClause="$setClause,${token}=${!token}"
		done
		setClause="Set $(tr '@' ' ' <<< "${setClause:1}")"
		dump -2 -n setClause -n -p

	## Build & run sqlStmt
		sqlStmt="$sqlAction $qaStatusTable $setClause $whereClause"
		RunSql2 $sqlStmt
		Msg3 $V1 "^^${sqlAction} of record completed"

	## Populate the testing detains table if workbook is finalized
		## Check to see if the workbook is finalized
		if [[ $(Contains "|${sheets}|" '|TestingDetailFinal|') == true ]]; then
			## Process the testing details records
			Msg3 "^^Processing Testing Details data via '$workerScript'..."
			ProtectedCall "Call "$workerScriptFile" "$workbook" 'TestingDetailFinal'"
			[[ $rc -ge 2 ]] && Msg3 $T "Processing the Testing Detail data, please review messages"
			if [[ $(Contains "$workbook" 'archive') == false ]]; then
				pushd $(dirname $workbook) >& /dev/null
				$DOIT mv -f $workbook "$qaTrackingRoot/Archive/"
				popd $(dirname $workbook) >& /dev/null
				## Get the key for the qastatus record
					whereClause="clientCode=$clientCode and product=$product and project=$project and instance=$instance and env=$env"
					sqlStmt="select idx from $qaStatusTable where $whereClause"
					RunSql2 $sqlStmt
					if [[ ${#resultSet[@]} -eq 0 ]]; then
						Error "Could not retrieve record key in $warehouseDb.$qaStatusTable for: $whereClause\nCould not set the record as deactivated"
					else
						qastatusKey=${resultSet[0]}
						sqlStmt="update $qaStatusTable set recordStatus=\"D\" where idx=$qastatusKey"
						RunSql2 $sqlStmt
					fi
			fi
		fi
	((fileCntr+=1))
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
## Fri Mar 17 08:42:05 CDT 2017 - dscudiero - Added sheetVersion
## Fri Mar 17 10:45:12 CDT 2017 - dscudiero - Fixed problem with doubly quotes strings## 03-24-2017 @ 09.10.05 - (1.1.11)    - dscudiero - General syncing of dev to prod
## 03-24-2017 @ 09.23.08 - (1.1.12)    - dscudiero - Fix problem setting the qastatus table record status=D
## 03-27-2017 @ 13.30.01 - (1.1.14)    - dscudiero - Only report on active records
## 04-03-2017 @ 07.45.53 - (1.1.15)    - dscudiero - Switch from RunSql to RunSql2
## 04-17-2017 @ 07.41.31 - (1.1.16)    - dscudiero - remove import fpr dump array, moved code to the Dump file
## 05-17-2017 @ 12.57.33 - (1.1.20)    - dscudiero - Fix problem parsing data for requester
## 05-17-2017 @ 16.08.34 - (1.1.25)    - dscudiero - Added support for the notes field
## 05-19-2017 @ 12.25.35 - (1.2.26)    - dscudiero - Added data from the implementation team's tracking spreadsheet
## 05-25-2017 @ 06.46.23 - (1.2.35)    - dscudiero - Remove jalot task number
## 06-05-2017 @ 12.53.26 - (1.2.36)    - dscudiero - Add parsing for 'Next' in the cell to trigger move to next
## 06-19-2017 @ 07.06.59 - (1.2.37)    - dscudiero - tweak formatting
## 09-29-2017 @ 10.14.39 - (1.2.45)    - dscudiero - Update FindExcecutable call for new syntax
## 10-31-2017 @ 10.57.06 - (1.2.52)    - dscudiero - Switch to Msg3
