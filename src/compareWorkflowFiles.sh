#!/bin/bash
#==================================================================================================
version=1.2.47 # -- dscudiero -- Fri 03/23/2018 @ 14:26:39.76
#==================================================================================================
TrapSigs 'on'
myIncludes="GetCims"
Import "$standardInteractiveIncludes $myIncludes"

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
# Declare local variables and constants
#==================================================================================================
## Get the files to act on from the database
	GetDefaultsData 'copyWorkflow'
	unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
	[[ $scriptData1 == '' ]] && Terminate "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
	requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

	[[ $scriptData2 == '' ]] && Terminate "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
	optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

	[[ $scriptData3 == '' ]] && Terminate "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
	requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

	[[ $scriptData4 == '' ]] && Terminate "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
	optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env,cims'
GetDefaultsData $myName
ParseArgsStd $originalArgStr
[[ $allItems == true ]] && allCims='allCims' || unset allCims

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
	Msg "Comparing CIM instance files..."
	for cim in $(tr ',' ' ' <<< $cimStr); do
		Msg "\n^Checking $(Upper $cim)..."
		foundDiff=false
		for file in  $(tr ',' ' ' <<< "$requiredInstanceFiles $optionalInstanceFiles"); do
			srcFile=$srcDir/web/$cim/$file
			tgtFile=$tgtDir/web/$cim/$file
			#dump -n file -t srcFile tgtFile
			[[ ! -f $srcFile ]] && continue
			[[ ! -f $tgtFile ]] && Warning 0 2 "'$file' exists in source but target file not found" && continue

			srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
			tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
			[[ $srcMd5 != $tgtMd5 ]] && Warning 0 2 "'${file}', files are different" || Msg "^^'${file}', files match"
		done
	done
fi

Msg "\nComparing 'shared' files..."
#srcDir=$skeletonRoot/release
for file in  $(tr ',' ' ' <<< "$requiredGlobalFiles $optionalGlobalFiles"); do
	srcFile=$srcDir/web${file}
	tgtFile=$tgtDir/web${file}
	#dump -n file -t srcFile tgtFile
	[[ ! -f $srcFile ]] && Msg "^^'${file}, not in source, skipping" && continue
	srcMd5=$(md5sum $srcFile | cut -f1 -d" ")
	[[ ! -f $tgtFile ]] && Msg "^^'${file}, not in target, skipping" && continue
	tgtMd5=$(md5sum $tgtFile | cut -f1 -d" ")
	[[ $srcMd5 != $tgtMd5 ]] && Warning 0 2 "'${file}', files are different" || Msg "^^'${file}', $(ColorI "files match")"
done


#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'# 09-24-2015 -- dscudiero -- New script to compare workflow files (1.1)
# 10-16-2015 -- dscudiero -- Update for framework 6 (1.2)
## Wed Apr 27 16:08:26 CDT 2016 - dscudiero - Switch to use RunSql
## Thu Apr 28 16:27:25 CDT 2016 - dscudiero - Cleanup and modernization
## Wed Mar 15 10:22:27 CDT 2017 - dscudiero - Updated to compare all the files processed in copyworkflow
## 03-20-2018 @ 09:03:02 - 1.2.44 - dscudiero - Tweak messaging, switch to Msg
## 03-22-2018 @ 12:36:01 - 1.2.46 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:33:10 - 1.2.47 - dscudiero - D
