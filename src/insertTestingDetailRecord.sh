#!/bin/bash
#DO NOT AUTPVERSION
#==================================================================================================
version=1.0.120 # -- dscudiero -- Wed 01/10/2018 @  8:14:08.26
#==================================================================================================
TrapSigs 'on'
myIncludes="RunSql2 GetExcel2 ProtectedCall"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
# NOT MEANT TO BE CALLED STAND ALONE
#==================================================================================================
checkParent="buildQaStatusTable"; found=false
for ((i=0; i<${#BASH_SOURCE[@]}; i++)); do [[ "$(basename "${BASH_SOURCE[$i]}")" == "${checkParent}.sh" ]] && found=true; done
[[ $found != true ]] && Terminate "Sorry, this script can only be called from '$checkParent'"

#==================================================================================================
# Standard call back functions
#==================================================================================================
function insertTestingDetailRecord-Goodbye { # or Goodbye-local
	[[ -f tmpFile ]] && rm -f $tmpFile
	return 0
}
function insertTestingDetailRecord-testMode { # or testMode-local
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
clientCode="$1"; shift
product="$1"; shift
instance="$1"; shift
project="$1"; shift
dump -2 workbookFile -t clientCode product project instance

## Get the key for the qastatus record
	Verbose 1 "^^^Retrieving qaStatusKey for '$clientCode.$product.$project.$instance'..."
	whereClause="clientCode=\"$clientCode\" and  product=\"$product\" and project=\"$project\" and instance=\"$instance\""
	sqlStmt="select idx from $qaStatusTable where $whereClause"
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -eq 0 ]] && Error "Could not retrieve record key in $warehouseDb.$qaStatusTable for:\n^$whereClause" && Goodbye 'Return' && return 2
	qastatusKey=${resultSet[0]}
	dump -2 -t -t qastatusKey

## Check to see if we have already processed this key
	sqlStmt="select count(*) from $qaTestingDetailsTable where qatestid=$qastatusKey"
	RunSql2 $sqlStmt
	[[ ${resultSet[0]} -gt 0 ]] && Warning 0 2 "QaTestId '$qastatusKey' has already been processed into '$warehouseDb.$qaTestingDetailsTable', skipping file" && Goodbye 'Return' && return 1

## Read the Testing Detail Final data
	Verbose 1 "^^^^Parsing '$workSheet' worksheet..."
	GetExcel2 -wb "$workbookFile" -ws "$workSheet"
	# grepStr=$(ProtectedCall "grep '*Fatal Error*' $tmpFile")
	# [[ $grepStr == '' ]] && grepStr=$(ProtectedCall "grep 'usage:' $tmpFile")
	# if [[ $grepStr != '' || $(tail -n 1 $tmpFile) == '-1' ]]; then
	# 	Error "Could not retrieve data from workbook, please see below"
	# 	tail -n 20 $tmpFile 2>&1 | xargs -I{} printf "\\t%s\\n" "{}"
	# 	Msg3
	# 	Goodbye -1
	# fi
	Verbose 1 "^^^^${#resultSet[@]} Records read from worksheet"
	## Loop through the lines, parseing data
	## line = testCaseid|testDescrpton|howToTest|overallStatus|iterationStatus|iterationDate|iterationPhase|iterationPhaseQualifier|
	insertCntr=0
	for ((i=0; i<${#resultSet[@]}; i++)); do
		line="${resultSet[$i]}"
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

		dump -2 -n -n line -t testCaseId description overallStatus iterationStatus iterationDate iterationPhase iterationPhaseQualifier
		previousTestCaseId="$testCaseId"
		previousOverallStatus="$overallStatus"

		## Quote text variables
		quoteFields='description overallStatus iterationStatus iterationDate iterationPhase iterationPhaseQualifier'
		for field in $quoteFields; do
			if [[ ${!field} != 'NULL' ]]; then
				tmpStr="\"${!field}\""
				tmpStr=$(sed s"/'/\\\'/"g <<< $tmpStr)
				eval $field=\'$tmpStr\'
			fi
		done

		values="NULL,$qastatusKey,$testCaseId,$description,$overallStatus,$iterationStatus,$iterationDate,$iterationPhase,$iterationPhaseQualifier"
		values="$values,NULL,NULL,NULL,NULL"
		sqlStmt="insert into $qaTestingDetailsTable values($values)"
		RunSql2 $sqlStmt
		(( insertCntr += 1))
	done ## resultSet
	Verbose 1 "^^^^$insertCntr records inserted into the $warehouseDb.$qaTestingDetailsTable table for qaStatus key qastatusKey"

	## Update the fixedDate, fixedPhase, and fixedPhaseQualifier columns
	## Find the test inances that failed
	updateCntr=0
	unset updatedList
	sqlStmt="select distinct testcaseid from $qaTestingDetailsTable where Lower(instanceStatus) like \"%failed%\""
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		Verbose 1 "^^^^Setting 'when fixed' data for failed test case instances ($(sed "s/ /, /g" <<< ${resultSet[*]}))..."
		## Loop through the failed records and retrieve the 'fixed on' information
		failedTestIds=(${resultSet[*]})
		for failedId in ${failedTestIds[@]}; do
			dump -2 failedId
			## OK get the fixed on data for each failed record
			fields="idx,instanceDate,instancePhase,instancePhaseQualifier"
			whereClause="Lower(instanceStatus) like \"%passed%\" and testcaseid=$failedId "
			sqlStmt="select $fields from $qaTestingDetailsTable where $whereClause order by instanceDate DESC;"
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -gt 0 ]]; then
				for result in "${resultSet[@]}"; do
					dump -2 -t result
					idx=$(cut -d'|' -f1 <<< "$result")
					instanceDate=$(cut -d'|' -f2 <<< "$result"); [[ $instanceDate  == '' ]] && instanceDate=NULL
					instancePhase=$(cut -d'|' -f3 <<< "$result"); [[ $instancePhase  == '' ]] && instancePhase=NULL
					instancePhaseQualifier=$(cut -d'|' -f4 <<< "$result"); [[ $instancePhaseQualifier  == '' ]] && instancePhaseQualifier=NULL
				done
				## Update the fixed data on all the testing records
				fields="fixedDate=\"$instanceDate\", fixedPhase=\"$instancePhase\", fixedPhaseQualifier=\"$instancePhaseQualifier\""
				sqlStmt="update $qaTestingDetailsTable set $fields where testcaseid=$failedId"
				RunSql2 $sqlStmt
				updatedList+=($failedId)
				(( updateCntr += 1))
			fi
		done
		Verbose 1 "^^^^$updateCntr records updated ($(sed "s/ /, /g" <<< ${updatedList[*]}))"
	fi

	[[ -f "$tmpFile" ]] && rm "$tmpFile"

#===================================================================================================
## Done
#===================================================================================================
 Goodbye 'Return'

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Oct 12 16:11:24 CDT 2016 - dscudiero - ETP process for QA Testing Details Table
## Mon Feb 13 16:12:33 CST 2017 - dscudiero - make sure we have our own tmpFile
## 03-24-2017 @ 07.36.41 - (1.0.104)   - dscudiero - escape single quotes in the text fields before sending to sql
## 03-24-2017 @ 07.53.01 - (1.0.105)   - dscudiero - General syncing of dev to prod
## 03-24-2017 @ 09.17.03 - (1.0.108)   - dscudiero - Tweak messaging
## 05-19-2017 @ 16.02.26 - (1.0.110)   - dscudiero - Remove dependence on jalot number
## 10-18-2017 @ 14.16.30 - (1.0.111)   - dscudiero - Make the 'called from' logic more robust
## 10-18-2017 @ 14.20.55 - (1.0.112)   - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 14.30.38 - (1.0.113)   - dscudiero - Fix who called check
## 10-19-2017 @ 09.42.47 - (1.0.114)   - dscudiero - Added debug arround caller check code
## 10-20-2017 @ 09.01.58 - (1.0.115)   - dscudiero - Fix problem in the caller check code
## 11-01-2017 @ 07.42.33 - (1.0.117)   - dscudiero - Switch to Msg3
## 11-08-2017 @ 07.32.09 - (1.0.118)   - dscudiero - Switch to GetExcel2
## 12-12-2017 @ 06.57.11 - (1.0.119)   - dscudiero - Remove 'env' from the queries
