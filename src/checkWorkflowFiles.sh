#!/bin/bash
#==================================================================================================
version=1.0.31 # -- dscudiero -- 12/14/2016 @ 11:19:56.73
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
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
searchFiles="$scriptData1"
triggerText='IDs CHANGED ON FORM FOR REFRESH'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
scriptHelpDesc="This script will scan the common workflow files looking for variables who's name has changed due to the CIM refresh project.\
\n\tThe script expectes to find a formatted comment block at the top of the custom.atj file."

GetDefaultsData $myName
ParseArgsStd
Hello
Init "getClient getEnv getDirs checkEnvs getCims"

unset verifyArgs
verifyArgs+=("Client:$client")
verifyArgs+=("Env:$(TitleCase $env)")
verifyArgs+=("CIMs:$cimStr")

VerifyContinue "You are asking to scan workflow files for changed variable names"
myData="Client: '$client', Env: '$env', Cims: '$cimStr' "
[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'data' $myLogRecordIdx "$myData"

#===================================================================================================
# Main
#===================================================================================================
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
