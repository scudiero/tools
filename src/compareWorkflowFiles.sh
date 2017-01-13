#!/bin/bash
#==================================================================================================
version=1.2.14 # -- dscudiero -- 01/12/2017 @ 12:59:19.16
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
imports="$imports GetCims"
Import "$imports"
originalArgStr="$*"
scriptDescription="Compare workflow files"

#==================================================================================================
# Compare workflow files
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# xx-xx-15 -- dgs - Initial coding
#==================================================================================================

#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function parseArgs-compareWorkflowFiles {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-all,1,switch,allCims,,,"Process all CIMs")
	}


#==================================================================================================
# Declare local variables and constants
#==================================================================================================
wfFiles="$scriptData1"
## Get the list of files to work with
	if [[ $wfFiles == '' ]]; then
		sqlStmt="select scriptData1 from $scriptsTable where name=\"copyWorkflow\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Msg2 $T "Could not retrieve workflow files data (scriptData1) from the $scriptsTable."
		wfFiles="${resultSet[0]}"
	fi

systemWfFiles="$scriptData2"
## Get the list of files to work with
	if [[ $systemWfFiles == '' ]]; then
		sqlStmt="select scriptData2 from $scriptsTable where name=\"copyWorkflow\""
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && Msg2 $T "Could not retrieve workflow files data (scriptData2) from the $scriptsTable."
		systemWfFiles="${resultSet[0]}"
	fi
#dump wfFiles systemWfFiles

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env,cims'
GetDefaultsData $myName
ParseArgsStd
[[ $allCims == true ]] && allCims='allCims' || unset allCims

Hello
Init "getClient getSrcEnv getTgtEnv getDirs checkEnvs getCims $allCims noWarn"

## Verify continue
unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
[[ $cimStr != '' ]] && verifyArgs+=("CIMs: $cimStr")
VerifyContinue "You are comparing CIM workflow files for:"

myData="Client: '$client', srcEnv: '$srcEnv', tgtEnv: '$tgtEnv'"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
## Main
#==================================================================================================
if [[ $cimStr != '' ]]; then
	Msg2 "Comparing CIM instances..."
	for cim in $(echo $cimStr | tr ',' ' '); do
		Msg2 "^$(Upper $cim)..."
		foundDiff=false
		for file in  $(echo $wfFiles | tr ',' ' '); do
			srcFile=$srcDir/web/$cim/$file
			tgtFile=$tgtDir/web/$cim/$file
			[[ ! -f $srcFile ]] && continue
			[[ ! -f $tgtFile ]] && Warning 0 2 "Source file '$srcFile' exists but target file not found" && continue

			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			[[ $srcMd5 != $tgtMd5 ]] && Warning 0 2 "File '$(ColorE $file)' is different" || Msg2 "^^$file is OK"
		done
	done
fi

Msg2
Msg2 "Comparing system files..."
srcDir=$skeletonRoot/release
for file in  $(echo $systemWfFiles | tr ',' ' '); do
	srcFile=$srcDir/web${file}
	tgtFile=$tgtDir/web${file}
	[[ ! -f $srcFile ]] && Msg2 "^Skipping file $file, not in source" && continue
	srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
	[[ ! -f $tgtFile ]] && Msg2 "^Skipping file $file, not in target" && continue
	tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
	Msg2 "^$file"
	[[ $srcMd5 != $tgtMd5 ]] && Msg2 $WT2 "File '$(ColorE $file)' is different" || Msg2 "^^$file is OK"
done


#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'# 09-24-2015 -- dscudiero -- New script to compare workflow files (1.1)
# 10-16-2015 -- dscudiero -- Update for framework 6 (1.2)
## Wed Apr 27 16:08:26 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Apr 28 16:27:25 CDT 2016 - dscudiero - Cleanup and modernization
