#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="1.0.118" # -- dscudiero -- Fri 05/26/2017 @ 10:19:16.40
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
	local callPgmName=$1; shift
	local searchMode=${1:-std}; shift
	local srcTypes="$1"; shift
	local srcLibs="$1"; shift
	local searchDirs searchMode srcTypes typeDir typeExt srcLibs localMd5 prodMd5 prodFile ans found searchDir type lib callPgmAlias
	#===================================================================================================================

	local useLocal=$USELOCAL
	local useDev=$USEDEV

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
		[[ $useDev == true && -d "$TOOLSDEVPATH/src" ]] && searchDirs="$TOOLSDEVPATH/src $searchDirs"
		[[ $TOOLSSRCPATH != '' && $searchMode != 'fast' ]] && searchDirs="$searchDirs $( tr ':' ' ' <<< $TOOLSSRCPATH)"

	## Check db to see if there is a script name override
		unset callPgmAlias
		sqlStmt="select exec from $scriptsTable where name =\"$callPgmName\" "
		RunSql2 $sqlStmt
		if [[ ${#resultSet[0]} -gt 0 && ${resultSet[0]} != 'NULL' ]]; then
			callPgmName="$(cut -d' ' -f1 <<< ${resultSet[0]})"
			callPgmAlias="$(cut -d' ' -f2 <<< ${resultSet[0]})"
		fi
		[[ $callPgmAlias != '' ]] && executeAlias="$callPgmAlias"

	## Search for execution file
		found=false;
	    for searchDir in $searchDirs ; do
	    	[[ ! -d $searchDir ]] && continue
	    	## Look for the '.sh' file in the root src directory, if found then use it
	    	executeFile="$searchDir/${callPgmName}.sh"
			if [[ -r "$executeFile" ]]; then
				found=true
				break
			else
				unset executeFile
			fi
			## Loop through library directories
	 	    for lib in $(tr ',' ' ' <<< $srcLibs); do
				## Look for the '.sh' file in the root lib directory, if found then use it
				executeFile="$searchDir/$lib/${callPgmName}.sh"
				if [[ -r "$executeFile" ]]; then
					found=true
					break
				else
					unset executeFile
				fi
				## Loop through the types
	 	    	for type in $(tr ',' ' ' <<< $srcTypes); do
					typeDir=$(cut -d':' -f1 <<< $type)
					typeExt=$(cut -d':' -f2 <<< $type)
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
					if [[ $useLocal != true && $useDev != true && $batchMode != true ]]; then
						Msg2 $N "\aFound a copy of '$callPgmName' in a local directory: '$(dirname $executeFile)'"
						[[ $batchMode != true ]] && unset ans && Prompt ans "'Yes' to use the local copy, 'No' to use production version" 'Yes No' 'Yes' '4' && ans=$(Lower ${ans:0:1})
					else
						ans='y'
					fi
					[[ $ans != 'y' ]] && executeFile=$prodFile || USELOCAL=true
				fi
			fi
		fi

	return 0
} ##FindExecutable
export -f FindExecutable

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Wed Jan  4 13:53:26 CST 2017 - dscudiero - General syncing of dev to prod
## 05-05-2017 @ 13.21.05 - ("1.0.101") - dscudiero - Remove GD code
## 05-12-2017 @ 14.58.09 - ("1.0.102") - dscudiero - misc changes to speed up
## 05-17-2017 @ 10.50.27 - ("1.0.116") - dscudiero - Update prompts to accomidate the new timed prompt support
## 05-26-2017 @ 10.31.55 - ("1.0.118") - dscudiero - Added --useDev support
