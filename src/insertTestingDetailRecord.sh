#!/bin/bash
#DO NOT AUTPVERSION
#==================================================================================================
version=1.0.101 # -- dscudiero -- 12/19/2016 @ 12:11:11.08
#==================================================================================================
TrapSigs 'on'
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
# NOT MEANT TO BE CALLED STAND ALONE
#==================================================================================================
checkParent="buildqastatustable.sh"; calledFrom="$(Lower "$(basename "${BASH_SOURCE[3]}")")"
[[ $(Lower $calledFrom) != $(Lower $checkParent)  ]] && Terminate "Sorry, this script can only be called from '$checkParent', \nCurrent call parent: '$calledFrom'"

#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-insertTestingDetailRecord  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-insertTestingDetailRecord  { # or Goodbye-local
	[[ -f tmpFile ]] && rm -f $tmpFile
	return 0
}
function testMode-insertTestingDetailRecord  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(MkTmpFile)
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#==================================================================================================
# Standard argument parsing and initialization
#==================================================================================================

#===================================================================================================
# Main
#===================================================================================================
workbookFile="$1"; shift
workSheet="$1"; shift

## Parse the workbook file name
fileName=$(basename $workbookFile)
fileName=$(cut -d'.' -f1 <<< $fileName)
clientCode=$(cut -d'-' -f1 <<< $fileName)
product=$(cut -d'-' -f2 <<< $fileName)
instance=$(cut -d'-' -f3 <<< $fileName)
project=$(cut -d'-' -f4 <<< $fileName)
env=$(cut -d'-' -f5 <<< $fileName)
jalotTaskNumber=$(cut -d'-' -f6 <<< $fileName)
	dump -2 workbookFile -t clientCode product project instance env jalotTaskNumber

## Get the key for the qastatus record
	Verbose 1 "^^^Retrieving qaStatusKey for '$clientCode.$product.$project.$instance.$env.$jalotTaskNumber'..."
	whereClause="clientCode=\"$clientCode\" and  product=\"$product\" and project=\"$project\" and instance=\"$instance\" and env=\"$env\" and jalotTaskNumber=\"$jalotTaskNumber\" "
	sqlStmt="select idx from $qaStatusTable where $whereClause"
	RunSql $sqlStmt
	[[ ${#resultSet[@]} -eq 0 ]] && Error "Could not retrieve record key in $warehouseDb.$qaStatusTable for:\n^$whereClause" && Goodbye 'Return' && return 2
	qastatusKey=${resultSet[0]}
	dump -2 -t -t qastatusKey

## Check to see if we have already processed this key
	sqlStmt="select count(*) from $qaTestingDetailsTable where qatestid=$qastatusKey"
	RunSql $sqlStmt
	[[ ${resultSet[0]} -gt 0 ]] && Msg2 $WT2 "QaTestId '$qastatusKey' has already been processed, skipping file" && Goodbye 'Return' && return 1

## Read the Testing Detail Final data
	Verbose 1 "^^^^Parsing '$workSheet' worksheet..."
	GetExcel "$workbookFile" "$workSheet" '^' > $tmpFile
	grepStr=$(ProtectedCall "grep '*Fatal Error*' $tmpFile")
	[[ $grepStr == '' ]] && grepStr=$(ProtectedCall "grep 'usage:' $tmpFile")
	if [[ $grepStr != '' || $(tail -n 1 $tmpFile) == '-1' ]]; then
		Error "Could not retrieve data from workbook, please see below"
		tail -n 20 $tmpFile 2>&1 | xargs -I{} printf "\\t%s\\n" "{}"
		Msg2
		Goodbye -1
	fi
	Verbose 1 "^^^^$(wc -l $tmpFile | cut -d' ' -f1) Records read from worksheet"
	## Loop through the lines, parseing data
	## line = testCaseid|testDescrpton|howToTest|overallStatus|iterationStatus|iterationDate|iterationPhase|iterationPhaseQualifier|
	insertCntr=0
	while read line; do
		testCaseId=$(cut -d'^' -f1 <<< $line); testCaseId=$(cut -d'.' -f1 <<< $testCaseId)
		[[ $testCaseId == 'Test Case #' ]] && continue
		description=$(cut -d'^' -f2 <<< $line) ;
		[[ $description == '( Add new test case )' || ${description:0:1} == '#' ]] && continue
		if [[ $description == '' ]]; then
			description='NULL'
		else
			## Escape quotes
			description=$(sed "s/'/\\\'/g" <<< "$description")
			description=$(sed 's/"/\\\"/g' <<< "$description")
		fi

		overallStatus=$(cut -d'^' -f4 <<< $line) ; [[ $overallStatus == '' ]] && overallStatus='NULL'
		iterationStatus=$(cut -d'^' -f5 <<< $line) ; [[ $iterationStatus == '' ]] && iterationStatus='NULL'
		iterationDate=$(cut -d'^' -f6 <<< $line) ; [[ $iterationDate == '' ]] && iterationDate='NULL'
		iterationPhase=$(cut -d'^' -f7 <<< $line) ; [[ $iterationPhase == '' ]] && iterationPhase='NULL'
		iterationPhaseQualifier=$(cut -d'^' -f8 <<< $line) ; [[ $iterationPhaseQualifier == '' ]] && iterationPhaseQualifier='NULL'
		[[ $overallStatus == 'NULL' && $iterationStatus == 'NULL' && $iterationDate == 'NULL' && $iterationPhase == 'NULL' && $iterationPhaseQualifier == 'NULL' ]] && continue

		[[ $testCaseId == '' ]] && testCaseId="$previousTestCaseId"
		[[ $overallStatus == '' ]] && overallStatus="$previousOverallStatus"

		dump -1 -n -n line -t testCaseId description overallStatus iterationStatus iterationDate iterationPhase iterationPhaseQualifier
		previousTestCaseId="$testCaseId"
		previousOverallStatus="$overallStatus"

		## Quote text variables
		quoteFields='description overallStatus iterationStatus iterationDate iterationPhase iterationPhaseQualifier'
		for field in $quoteFields; do
			if [[ ${!field} != 'NULL' ]]; then
				tmpStr="\"${!field}\""
				eval $field=\'$tmpStr\'
			fi
		done

		values="NULL,$qastatusKey,$testCaseId,$description,$overallStatus,$iterationStatus,$iterationDate,$iterationPhase,$iterationPhaseQualifier"
		values="$values,NULL,NULL,NULL,NULL"
		sqlStmt="insert into $qaTestingDetailsTable values($values)"
		RunSql $sqlStmt
		(( insertCntr += 1))
	done < $tmpFile
	Verbose 1 "^^^^$insertCntr records inserted into the $warehouseDb.$qaTestingDetailsTable table"

	## Update the fixedDate, fixedPhase, and fixedPhaseQualifier columns
	## Find the test inances that failed
	updateCntr=0
	unset updatedList
	sqlStmt="select distinct testcaseid from $qaTestingDetailsTable where Lower(instanceStatus) like \"%failed%\""
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		Verbose 1 "^^^^Setting 'fixed' data for failed test case instances ($(sed "s/ /, /g" <<< ${resultSet[*]}))..."
		## Loop through the failed records and retrieve the 'fixed on' information
		failedTestIds=(${resultSet[*]})
		for failedId in ${failedTestIds[@]}; do
			dump -1 failedId
			## OK get the fixed on data for each failed record
			fields="idx,instanceDate,instancePhase,instancePhaseQualifier"
			whereClause="Lower(instanceStatus) like \"%passed%\" and testcaseid=$failedId "
			sqlStmt="select $fields from $qaTestingDetailsTable where $whereClause order by instanceDate DESC;"
			RunSql $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				for result in "${resultSet[@]}"; do
					dump -1 -t result
					idx=$(cut -d'|' -f1 <<< "$result")
					instanceDate=$(cut -d'|' -f2 <<< "$result"); [[ $instanceDate  == '' ]] && instanceDate=NULL
					instancePhase=$(cut -d'|' -f3 <<< "$result"); [[ $instancePhase  == '' ]] && instancePhase=NULL
					instancePhaseQualifier=$(cut -d'|' -f4 <<< "$result"); [[ $instancePhaseQualifier  == '' ]] && instancePhaseQualifier=NULL
				done
				## Update the fixed data on all the testing records
				fields="fixedDate=\"$instanceDate\", fixedPhase=\"$instancePhase\", fixedPhaseQualifier=\"$instancePhaseQualifier\""
				sqlStmt="update $qaTestingDetailsTable set $fields where testcaseid=$failedId"
				RunSql $sqlStmt
				updatedList+=($failedId)
				(( updateCntr += 1))
			fi
		done
		Verbose 1 "^^^^$updateCntr records updated ($(sed "s/ /, /g" <<< ${updatedList[*]}))"
	fi

#===================================================================================================
## Done
#===================================================================================================
return 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Oct 12 16:11:24 CDT 2016 - dscudiero - ETP process for QA Testing Details Table
