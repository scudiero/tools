#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="1.0.100" # -- dscudiero -- 01/12/2017 @ 12:51:44.85
#=======================================================================================================================
# Find the execution file
# Usage: FindExecutable "$callPgmName" "$extensions" "$libs"
#	callPgmName	- The name of the program to search for
#	searchMode	- In the set {'fast','std'}, fast will only search public $TOOLSPATH/src directory
#	searchTypes	- A comma separated list of Type:extension pairs.  e.g 'Bash:sh,Python:py,Java:class'
#	srcLibs		- A comma separated list of src subdirectories to search.  In the set {'cron','features','reports','patches'}
#
# Search directories defined by $TOOLSSRC, defaults to $TOOLSPATH
# Returns file in variable 'executeFile' and optionally 'executeAlias' if the program is aliased in the scripts table
#=======================================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#=======================================================================================================================
function FindExecutable {
	Import RunSql2 Prompt VerifyPromptVal Goodbye
	#===================================================================================================================
	local GD='GD echo'
	#local GD='echo'
	$GD ">>> $FUNCNAME -- Starting: \$* = '$*' <<<"
	local callPgmName=$1; shift
	local searchMode=${1:-std}; shift
	local srcTypes="$1"; shift
	local srcLibs="$1"; shift
	local searchDirs searchMode srcTypes typeDir typeExt srcLibs localMd5 prodMd5 prodFile ans found searchDir type lib callPgmAlias useLocal
	#===================================================================================================================

	useLocal=$USELOCAL

	if [[ $srcTypes == '' || $srcTypes == 'search' || $srcLibs == '' ]]; then
		sqlStmt="select scriptData1,scriptData2 from $scriptsTable where name =\"dispatcher\" "
		RunSql2 $sqlStmt
	 	resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString")
		local dbSrcTypes="$(cut -d'|' -f1 <<< "$resultString")"
		local dbSrcLibs="$(cut -d'|' -f2 <<< "$resultString")"
	fi
	[[ $srcTypes == '' || $srcTypes == 'search' ]] && srcTypes="$dbSrcTypes"
	[[ $srcLibs == '' ]] && srcLibs="$dbSrcLibs"

	## Search for the file scanning TOOLSSRC, TOOSSRCLIBS
		searchDirs="$TOOLSPATH/src"
		[[ $TOOLSSRCPATH != '' && $searchMode != 'fast' ]] && searchDirs=($( tr ':' ' ' <<< $TOOLSSRCPATH))
		$GD -e "\tcallPgmName: '$callPgmName' \n\tsearchMode: '$searchMode' \n\tsrcTypes: '$srcTypes' \n\tsearchDirs: '$searchDirs' \n\tsrcLibs: '$srcLibs'"

	## Check db to see if there is a script name override
		unset callPgmAlias
		sqlStmt="select exec from $scriptsTable where name =\"$callPgmName\" "
		RunSql2 $sqlStmt
		if [[ ${#resultSet[0]} -gt 0 && ${resultSet[0]} != 'NULL' ]]; then
			callPgmName="$(cut -d' ' -f1 <<< ${resultSet[0]})"
			callPgmAlias="$(cut -d' ' -f2 <<< ${resultSet[0]})"
		fi
		[[ $callPgmAlias != '' ]] && executeAlias="$callPgmAlias"
		$GD -e "\n\tResoloved: \n\t\tcallPgmName: $callPgmName \n\t\tcallPgmAlias: $callPgmAlias\n"

	## Search for execution file
		found=false;
	    for searchDir in $( tr ':' ' ' <<< $TOOLSSRCPATH) $TOOLSPATH/src; do
	    	[[ ! -d $searchDir ]] && continue
			$GD -e "\tSearching: '$searchDir'..."
	    	## Look for the '.sh' file in the root src directory, if found then use it
	    	executeFile="$searchDir/${callPgmName}.sh"
			if [[ -r "$executeFile" ]]; then
				$GD -e "\t\tFound executable in the primary src directory, using that file"
				found=true
				break
			else
				unset executeFile
			fi
			## Loop through library directories
	 	    for lib in $(tr ',' ' ' <<< $srcLibs); do
	 	    	$GD -e "\t\tlib: '$lib'"
				## Look for the '.sh' file in the root lib directory, if found then use it
				executeFile="$searchDir/$lib/${callPgmName}.sh"
				if [[ -r "$executeFile" ]]; then
					$GD -e "\t\tFound executable in the root src/$lib directory, using that file"
					found=true
					break
				else
					unset executeFile
				fi
				## Loop through the types
	 	    	for type in $(tr ',' ' ' <<< $srcTypes); do
					typeDir=$(cut -d':' -f1 <<< $type)
					typeExt=$(cut -d':' -f2 <<< $type)
					$GD -e "\t\ttype: '$type',\ttypeDir: '$typeDir',\ttypeExt: '$typeExt'\n\t\t\t$executeFile"
	 	    		## Look for the '.sh' file in the root src directory, if found then use it
					executeFile="$searchDir/$typeDir/${callPgmName}.${typeExt}"
					if [[ -r "$executeFile" ]]; then
						found=true
						break
					else
						unset executeFile
					fi
				done ## types
				[[ $found == true ]] && break
	 	    done ## libs
			[[ $found == true ]] && break
	 	done  ## searchDirs

	    if [[ $found == false ]]; then
	    	ErrorMsg "($FUNCNAME) Could not resolve the script source file for '$callPgmName'"
	    	Msg2 "^searchMode: '$searchMode'"
	    	Msg2 "^searchDirs: '$searchDirs'"
	    	Msg2 "^srcTypes: '$srcTypes'"
	    	Msg2 "^srcLibs: '$srcLibs'"
	    	Goodbye -1
	    fi

	## Check to see if file was found in directory other than $TOOLSPATH
		if [[ $(dirname $executeFile) != $TOOLSPATH ]]; then
			localMd5=$(cut -d' ' -f1 <<< $(md5sum $executeFile))
			prodFile=$TOOLSPATH/src/$(basename $executeFile)
			unset prodMd5
			## If we have a prod file then see if the local file is different
			if [[ -x $prodFile ]]; then
				prodMd5=$(cut -d' ' -f1 <<< $(md5sum $prodFile))
				## Check md5's to see if different from production file
				if [[ $prodMd5 != $localMd5 ]]; then
					unset ans
					if [[ $useLocal != true && $batchMode != true ]]; then
						Msg2 $N "\aFound a copy of '$callPgmName' in a local directory: '$(dirname $executeFile)'"
						[[ $batchMode != true ]] && Prompt ans 'Do you want to use the dev/local copy ?' 'Yes No' 'Yes' '3'; ans=$(Lower ${ans:0:1}) || ans='y'
					else
						ans='y'
					fi
					[[ $ans != 'y' ]] && executeFile=$prodFile
				fi
			fi
		fi
	$GD -e "\n=== Resolved execution file: '$executeFile' ==========================================================="

	return 0
} ##FindExecutable
export -f FindExecutable

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Wed Jan  4 13:53:26 CST 2017 - dscudiero - General syncing of dev to prod
