#!/bin/bash
#==================================================================================================
version=1.2.42 # -- dscudiero -- Thu 09/14/2017 @ 15:33:53.87
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue'
includes="$includes GetCims"
Import "$includes"
originalArgStr="$*"
scriptDescription="Compare workflow related files between two environments"

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
## Get the files to act on from the database
GetDefaultsData 'copyWorkflow'
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
	[[ $scriptData1 == '' ]] && Msg2 $T "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

	[[ $scriptData2 == '' ]] && Msg2 $T "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

	[[ $scriptData3 == '' ]] && Msg2 $T "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

	[[ $scriptData4 == '' ]] && Msg2 $T "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env,cims'
GetDefaultsData $myName
ParseArgsStd
[[ $allCims == true ]] && allCims='allCims' || unset allCims

Hello
Init "getClient getSrcEnv getTgtEnv getDirs checkEnvs getCims $allCims noWarn"
dump -1 requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles

## Verify continue
unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Source Env:$(TitleCase $srcEnv) ($srcDir)")
verifyArgs+=("Target Env:$(TitleCase $tgtEnv) ($tgtDir)")
[[ $cimStr != '' ]] && verifyArgs+=("CIMs: $cimStr")
verifyContinueDefault='Yes'
VerifyContinue "You are comparing CIM workflow files for:"

myData="Client: '$client', srcEnv: '$srcEnv', tgtEnv: '$tgtEnv'"
[[ $logInDb != false && $myLogRecordIdx != "" && $testMode != true ]] && dbLog 'data' $myLogRecordIdx "$myData"

#==================================================================================================
## Main
#==================================================================================================
if [[ $cimStr != '' ]]; then
	Msg2 "Comparing CIM instance files..."
	for cim in $(tr ',' ' ' <<< $cimStr); do
		Msg2 "\n^Checking $(Upper $cim)..."
		foundDiff=false
		for file in  $(tr ',' ' ' <<< "$requiredInstanceFiles $optionalInstanceFiles"); do
			srcFile=$srcDir/web/$cim/$file
			tgtFile=$tgtDir/web/$cim/$file
			#dump -n file -t srcFile tgtFile
			[[ ! -f $srcFile ]] && continue
			[[ ! -f $tgtFile ]] && Warning 0 2 "'$file' exists in source but target file not found" && continue

			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			[[ $srcMd5 != $tgtMd5 ]] && Warning 0 2 "'${file}', files are different" || Msg2 "^^'${file}', files match"
		done
	done
fi

Msg2 "\nComparing 'shared' files..."
#srcDir=$skeletonRoot/release
for file in  $(tr ',' ' ' <<< "$requiredGlobalFiles $optionalGlobalFiles"); do
	srcFile=$srcDir/web${file}
	tgtFile=$tgtDir/web${file}
	#dump -n file -t srcFile tgtFile
	[[ ! -f $srcFile ]] && Msg2 "^'${file}, not in source, skipping" && continue
	srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
	[[ ! -f $tgtFile ]] && Msg2 "^'${file}, not in target, skipping" && continue
	tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
	[[ $srcMd5 != $tgtMd5 ]] && Warning 0 2 "'${file}', files are different" || Msg2 "^^'${file}', files match"
done


#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'# 09-24-2015 -- dscudiero -- New script to compare workflow files (1.1)
# 10-16-2015 -- dscudiero -- Update for framework 6 (1.2)
## Wed Apr 27 16:08:26 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Apr 28 16:27:25 CDT 2016 - dscudiero - Cleanup and modernization
## Wed Mar 15 10:22:27 CDT 2017 - dscudiero - Updated to compare all the files processed in copyworkflow
