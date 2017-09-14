#!/bin/bash
#==================================================================================================
version=1.0.33 # -- dscudiero -- Thu 09/14/2017 @ 14:31:51.28
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye'
includes="$includes StringFunctions ProtectedCall RunSql2"
Import "$includes"
originalArgStr="$*"
scriptDescription="Scan workflow files for changed variable names"

#= Description +===================================================================================
# Scan workflow files looking for any occourances of variable names that have changed due to
# CIM refresh project rework
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-checkWorkflowFiles  { # or parseArgs-local
	#argList+=(-optionArg,1,option,scriptVar,,script,'Help text')
	#argList+=(-flagArg,2,switch,scriptVar,,script,'Help text')
	#argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
	return 0
}
function Goodbye-checkWorkflowFiles  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-checkWorkflowFiles  { # or testMode-local
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
	GetDefaultsData 'copyWorkflow'





function workflowcorefiles {
	local file srcFile tgtFile result changeLogRecs
	Init 'getClient getEnv getDirs checkEnv'
	echo

	local sqlStmt="select scriptData3 from $scriptsTable where name=\"copyWorkflow\""
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -eq 0 ]] && Terminate "Could not retrieve workflow files data (scriptData1) from the $scriptsTable.";
	local scriptData="$(cut -d':' -f2- <<< ${resultSet[0]})"

	for file in $(tr ',' ' ' <<< $scriptData); do
		[[ $file == 'roles.tcf' || ${file##*.} == 'plt' ]] && continue
		srcFile="$skeletonRoot/release/web${file}"
		tgtFile="$srcDir/web${file}"
		## Copy file if changed
			result=$(CopyFileWithCheck "$srcFile" "$tgtFile" 'backup')
			if [[ $result == true ]]; then
				changeLogRecs+=("Updated: $file")
				WriteChangelogEntry 'changeLogRecs' "$srcDir/changelog.txt"
				Msg2 "^'$file' copied"
			elif [[ $result == 'same' ]]; then
				Msg2 "^'$file' - md5's match, no changes made"
			else
				Msg2 $T "Error copying file:\n^$result"
			fi
	done
	return 0
}



#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
scriptHelpDesc="This script will scan the common workflow files looking for variables who's name has changed due to the CIM refresh project.\
\n\tThe script expectes to find a formatted comment block at the top of the custom.atj file."

GetDefaultsData 'copyWorkflow'
ParseArgsStd
Hello
Init "getClient getEnv getDirs checkEnvs getCims"

myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
unset requiredInstanceFiles optionalInstanceFiles requiredGlobalFiles optionalGlobalFiles ifThenDelete
[[ -z $scriptData1 ]] && Msg2 $T "'scriptData1 (requiredInstanceFiles)' is null, please check script configuration data"
requiredInstanceFiles="$(cut -d':' -f2- <<< $scriptData1)"

[[ -z $scriptData2 ]] && Msg2 $T "'scriptData2 (optionalInstanceFiles)' is null, please check script configuration data"
optionalInstanceFiles="$(cut -d':' -f2- <<< $scriptData2)"

[[ -z $scriptData3 ]] && Msg2 $T "'scriptData3 (requiredGlobalFiles)' is null, please check script configuration data"
requiredGlobalFiles="$(cut -d':' -f2- <<< $scriptData3)"

[[ -z $scriptData4 ]] && Msg2 $T "'scriptData4 (optionalGlobalFiles)' is null, please check script configuration data"
optionalGlobalFiles="$(cut -d':' -f2- <<< $scriptData4)"

srcDir=$skeletonRoot/release

for cim in $(tr ',' ' ' <<< $cimStr); do
	Msg2
	Msg2 "Processing: $cim..."
	## Check to see if the data is there
		customAtjFile="$siteDir/web/$cim/custom.atj"
		firstLine=$(head -n 1 $customAtjFile);
		[[ $(Contains "$firstLine" "$triggerText") != true ]] && Warning 0 1 "Could not locate variable map in the custom.atj file, skipping" && continue
	## Read/parse data to the first blank line, skipping first line
		while IFS='' read -r line || [[ -n "$line" ]]; do
		    [[ $line == '' ]] && break
		    oldVars+=($(cut -d' ' -f2 <<< $line))
		    newVars+=($(cut -d' ' -f4 <<< $line))
		done < <(tail -n +2 $customAtjFile)
	## Look for the variables in the workflow files
		for file in $(tr ',' ' ' <<< $searchFiles); do
			[[ ! -f "$siteDir/web/$cim/$file" ]] && continue
			putFileMsg=false
			for ((cntr=1; cntr<${#oldVars[@]}; cntr++)); do
				grepStr=$(ProtectedCall "grep -n ${oldVars[$cntr]} $siteDir/web/$cim/$file")
				if [[ $grepStr != '' ]]; then
					[[ $putFileMsg != true ]] && Msg2 "^$file" && putFileMsg=true
					Msg2 "^^${oldVars[$cntr]} ==> ${newVars[$cntr]}"
					echo "$grepStr" | xargs -I{} echo -e "\t\t{}"
				fi
			done
		done
done

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Fri Jul 15 16:00:34 CDT 2016 - dscudiero - Scan workflow files looking for variables with name changes due to the CIM refresh project
## Fri Jul 15 16:21:55 CDT 2016 - dscudiero - Only display the file name once
