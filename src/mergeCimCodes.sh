#!/bin/bash
#==================================================================================================
version=1.2.11 # -- dscudiero -- 03/15/2017 @ 14:51:15.42
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports GetOutputFile"
Import "$imports"
originalArgStr="$*"
scriptDescription="Merge CIM codes"

#==================================================================================================
# Merge cim code data (codedesc/cimlookup)
#==================================================================================================
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 11-25-15 -- dgs - Initial coding
#==================================================================================================
#==================================================================================================
# local functions
#==================================================================================================
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function parseArgs-mergeCimCodes  {
		argList+=(-informationOnly,2,switch,informationOnlyMode,,script,'Only analyze data and print error messages, do not change any client data.')
		argList+=(-database,2,option,database,,script,'The database to analyze, values can be cimcodes or cimlookup')
		return 0
	}

	#==============================================================================================
	# Goodbye call back
	#==============================================================================================
	function Goodbye-mergeCimCodes  {
		eval $errSigOn
		[[ -f $logFile && $outFile != '' ]] && cp -fp "$logFile" "$outFile"
		return 0
	}

	#==============================================================================================
	# TestMode overrides
	#==============================================================================================
	function testMode-mergeCimCodes  {
		srcEnv='dev'
		srcDir=~/testData/dev
		tgtEnv='test'
		tgtDir=~/testData/next
		return 0
	}


#==================================================================================================
# Declare local variables and constants
#==================================================================================================
trueVars=''
falseVars='informationOnlyMode allItems'
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done


#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
#helpNotes+=('1) If the noPrompt flag is active then the local repo will always be refreshed from the')
#helpNotes+=('   master before the copy step.')

GetDefaultsData $myName
ParseArgsStd

Hello

displayGoodbyeSummaryMessages=true
Init "getClient getSrcEnv getTgtEnv getDirs checkEnvs"
dump -1 client srcDir tgtDir informationOnlyMode allItems testMode

[[ -z $database ]] && database='cimcodes'
[[ $Contains 'cimcodes,cimlookup' "$database" != true ]] && Terminate "Invalid value specified for database, value may be 'cimcodes' or 'cimlookup'"

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
verifyArgs+=("database:$database")
[[ $informationOnlyMode == true ]] && verifyArgs+=("Information only mode:$informationOnlyMode")
[[ $allItems == true ]] && verifyArgs+=("Auto process all items:$allItems")
VerifyContinue "You are asking to merge CIM code (codedesc) data:"

myData="Client: '$client', srcEnv: '$srcEnv', tgtEnv: '$tgtEnv', informationOnlyMode: '$informationOnlyMode', allItems: '$allItems'"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

## Set output file
	outFile="$(GetOutputFile "$client" "$env" "$product")"

summaryMsgs+=("Client:$client")
summaryMsgs+=("Source Env: $(TitleCase $srcEnv) ($srcDir)t")
summaryMsgs+=("Target Env: $(TitleCase $tgtEnv) ($tgtDir)")
[[ $informationOnlyMode == true ]] && summaryMsgs+=("Information only mode: $informationOnlyMode")
[[ $allItems == true ]] && summaryMsgs+=("Auto process all items: $allItems")
summaryMsgs+=("Output written to: $outFile")
Msg2

#==================================================================================================
# Main
#==================================================================================================
[[ $database == 'cimcodes' ]] && database='codedesc' || database='cimlookupkup'

## Retrieve source data
	declare -A srcData
	unset srcKeys
	srcSqlFile=$srcDir/db/cimcourses.sqlite
	[[ ! -r $srcSqlFile ]] && Terminate "Could not open source sql file\n\t'$srcSqlFile'"
	sqlStmt="select count(*) key from $database"
	RunSql2 "$srcSqlFile" "$sqlStmt"
	numSrcRecords=${resultSet[0]}

	Msg2; Msg2 "Fetching source data ($numSrcRecords records)..."
	fields="setname,groupname,code,name,rank,siscode,access"
	sqlStmt="select $fields from $database order by setname,code"
	RunSql2 "$srcSqlFile" "$sqlStmt"
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "No records returned from source database"
	Msg2 "Building source ($(TitleCase $srcEnv)) data hash table..."
	for result in "${resultSet[@]}"; do
	 	resultString=$result; resultString=$(echo "$resultString" | tr "\t" "|" )
		dump -2 -n -t resultString
		setname="$(echo "$resultString" | cut -d'|' -f1)"
		code="$(echo "$resultString" | cut -d'|' -f3)"
		## Check to see if we have duplicatge keys
		[[ ${srcData["$setname:$code"]+abc} ]] && Terminate "Found duplicate source records for: setname='$setname', code='$code' \
		\n\tPrevious Record: '${srcData["$setname:$code"]}'\n\tCurrent Record:  '$resultString'"
		srcData["$setname:$code"]=$"$resultString"
		srcKeys+=("$setname:$code")
	done
	Msg2 "^Retrieved ${#srcData[@]} records"
	IFSave="$IFS"; IFS=$'\n' sorted_arr=($(printf '%s\n' ${srcKeys[@]} | sort -n)); IFS=$IFSave; srcKeys=$sorted_arr;
	if [[ $verboseLevel -ge 1 ]]; then Msg2 "^Sorted srcData hash:"; for i in "${srcKeys[@]}"; do printf "\t\t[$i] = >${srcData[$i]}<\n"; done; fi

## Retrieve target data
	declare -A tgtData
	declare -A tgtSetnames ## Hash table to check if a setname is defined in the tgt env
	unset tgtKeys
	fields="key,setname,groupname,code,name,rank,siscode,access"
	tgtSqlFile=$tgtDir/db/cimcourses.sqlite
	[[ ! -r $tgtSqlFile ]] && Terminate "Could not open target sql file\n\t'$tgtSqlFile'"
	sqlStmt="select count(*) key from $database"
	RunSql2 "$tgtSqlFile" "$sqlStmt"
	numTgtRecords=${resultSet[0]}

	Msg2; Msg2 "Fetching target ($(TitleCase $tgtEnv)) data ($numTgtRecords records)..."
	sqlStmt="select $fields from $database order by setname,code"
	RunSql2 "$tgtSqlFile" "$sqlStmt"
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "No records returned from source database"
	Msg2 "Building target data hash table..."
	for result in "${resultSet[@]}"; do
	 	resultString=$result; resultString=$(echo "$resultString" | tr "\t" "|" )
		dump -2 -n -t resultString
		setname="$(echo "$resultString" | cut -d'|' -f2)"
		code="$(echo "$resultString" | cut -d'|' -f4)"
		tgtData["$setname:$code"]=$"$resultString"
		tgtSetnames[$setname]=true
		tgtKeys+=("$setname:$code")
	done
	Msg2 "^Retrieved ${#tgtData[@]} records"
	IFSave="$IFS"; IFS=$'\n' sorted_arr=($(printf '%s\n' ${tgtKeys[@]} | sort -n)); IFS=$IFSave; tgtKeys=$sorted_arr;
	if [[ $verboseLevel -ge 1 ]]; then Msg2 "^Sorted tgtData hash:"; for i in "${tgtKeys[@]}"; do printf "\t\t[$i] = >${tgtData[$i]}<\n"; done; fi
	if [[ $verboseLevel -ge 1 ]]; then Msg2 "^tgtSetnames hash:"; for i in "${!tgtSetnames[@]}"; do printf "\t\t[$i] = >${tgtSetnames[$i]}<\n"; done; fi

## Compare and Merge the data
	targetBackedUp=false
	numAdded=0; numUpdated=0; numSkipped=0; numMatched=0;
	Msg2; Msg2 "Merging source data ($numSrcRecords records)..."
	[[ $targetBackedUp == false ]] && BackupCourseleafFile $tgtSqlFile && targetBackedUp=true
	unset oldSrcSetName recordCounter
	for key in "${srcKeys[@]}"; do
		srcSetname="$(echo "$key" | cut -d':' -f 1)"
		srcCode="$(echo "$key" | cut -d':' -f 2)"
		srcString=$"${srcData["$key"]}"
		srcGroupname="$(echo $srcString | cut -d'|' -f 2)"
		srcName="$(echo $srcString | cut -d'|' -f 4)"
		srcRank="$(echo $srcString | cut -d'|' -f 5)"
		srcSiscode="$(echo $srcString | cut -d'|' -f 6)"
		srsAccess="$(echo $srcString | cut -d'|' -f 7)"
		tgtString=$"$(echo ${tgtData["$key"]} | cut -d'|' -f 2-)"
		tgtDbKey="$(echo ${tgtData["$key"]}| cut -d'|' -f 1)"
		Verbose "\n[$key]\n"; dump -1 -t srcString tgtString srcCode srcGroupname srcName srcRank srcSiscode srsAccess tgtDbKey oldSrcSetName

		if [[ ${tgtData["$key"]+abc} ]]; then
			## Source and target keys found -- merge
			if [[ $"$srcString" != $"$tgtString" ]]; then
				Msg2
				Msg2 "^Found different data for setname: '$srcSetname', code: '$srcCode'"
				Msg2 "^^srcData ($(TitleCase $srcEnv)) : $srcString"
				Msg2 "^^tgtData ($(TitleCase $tgtEnv)) : $tgtString"
				[[ $allItems == true ]] && ans='y' || unset ans
				[[ $informationOnlyMode != true && $allItems != true ]] && Prompt ans "\tDo you wish to insert the record" 'Yes No'; ans=$(Lower ${ans:0:1})
				if [[ $(Lower ${ans:0:1}) == 'y' ]]; then
					sqlStmt="update $database set setname=\"$srcSetname\", groupname=\"$srcGroupname\", code=\"$srcCode\", name=\"$srcName\", rank=\"$srcRank\",\
							siscode=\"$srcSiscode\",access=\"$srcAccess\" where key=\"$tgtDbKey\""
					RunSql2 "$tgtSqlFile" "$sqlStmt"
					ProtectedCall "((numUpdated++))"
				else
					ProtectedCall "((numSkipped++))"
				fi
			else
				ProtectedCall "((numMatched++))"
			fi #[[ $srcString != $tgtString ]]
		else
			## New target element
			if [[ ${tgtSetnames[$srcSetname]} != true ]]; then
				## New target setname, just add it
				Msg2; Msg2 "^Found new setname: '$srcSetname'"
				Msg2 "^^Adding: [$key] = '${srcData[$key]}'"
				sqlStmt="insert into $database values(NULL,\"$srcSetname\",\"$srcGroupname\",\"$srcCode\",\"$srcName\",\"$srcRank\",\"$srcSiscode\",\"$srcAccess\")"
				[[ $informationOnlyMode != true ]] && RunSql2 "$tgtSqlFile" "$sqlStmt" && ProtectedCall "((numAdded++))" || ProtectedCall "((numSkipped++))"
			else
				## Existing setname, new data, prompt user
				Msg2; Msg2 "^Found new data for setname: '$srcSetname'"
				Msg2 "^^srcData ($(TitleCase $srcEnv)) : $srcString"
				[[ $allItems == true ]] && ans='y' || unset ans
				if [[ $informationOnlyMode != true && $allItems != true ]]; then
					if [[ $srcSetname != $oldSrcSetName || $doAllSetName != true ]]; then
						Prompt ans "\tDo you wish to insert the record" 'Yes No AllofThisSetName'; ans=$(Lower ${ans:0:1})
						[[ $ans == 'a' ]] && ans='y' && doAllSetName=true || doAllSetName=false
					else
						ans='y'
					fi
				fi
				if [[ $ans == 'y' ]]; then
					sqlStmt="insert into $database values(NULL,\"$srcSetname\",\"$srcGroupname\",\"$srcCode\",\"$srcName\",\"$srcRank\",\"$srcSiscode\",\"$srcAccess\")"
					RunSql2 "$tgtSqlFile" "$sqlStmt"
					ProtectedCall "((numAdded++))"
				else
					ProtectedCall "((numSkipped++))"
				fi
			fi #[[ ${tgtSetnames[$srcSetname]} != true ]]
			oldSrcSetName="$srcSetname"
		fi #[[ ${tgtData["$key"]+abc} ]]

		ProtectedCall "((recordCounter++))"
		[[ $(($recordCounter % 100)) -eq 0 ]] && Info 0 1 "Processed $recordCounter out of ${#srcData[@]} records..."
	done
Msg2 "Processing Completed"

## Write out change log entries
	if [[ $informationOnlyMode != true && $testMode != true ]]  && [[ $numUpdated -gt 0 ||  $numAdded -gt 0 ]]; then
		Msg2; Msg2 "$userName\t$(date)" >> $tgtDir/changelog.txt
		Msg2 "^$myName merged data from '$(TitleCase $srcEnv)'" >> $tgtDir/changelog.txt
		[[ $numUpdated -gt 0 ]] && Msg2 "^^Updated $numUpdated records" >> $tgtDir/changelog.txt
		[[ $numAdded -gt 0 ]] && Msg2 "^^Added $numAdded records" >> $tgtDir/changelog.txt
		if [[ -f $logFile && -d $tgtDir/attic ]]; then
			cp -fp "$logFile" "$tgtDir/attic/$(basename $outFile)"
			Msg2 "^^See: $tgtDir/attic/$(basename $outFile)" >> $tgtDir/changelog.txt
		fi
	fi

## Summary messages
	summaryMsgs+=("")
	summaryMsgs+=("Matched $numMatched records")
	summaryMsgs+=("Updated $numUpdated records")
	summaryMsgs+=("Added $numAdded records")
	summaryMsgs+=("Skipped $numSkipped records")
	[[ $testMode == true ]] && summaryMsgs+=("Note: TestMode flag was active, no data has been changed.")

#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================
# 11-30-2015 -- dscudiero -- Merge CIM codes (1.1)
# 11-30-2015 -- dscudiero -- New script to merge CIM codes DBs (1.1)
# 12-09-2015 -- dscudiero -- Heavily refactored, sorted key list, etc. (1.2)
## Wed Apr 27 16:33:07 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Aug  4 11:02:05 CDT 2016 - dscudiero - Added displayGoodbyeSummaryMessages=true
## Thu Mar 16 08:13:57 CDT 2017 - dscudiero - add ability to pass in the database to merge
