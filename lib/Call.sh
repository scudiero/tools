#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
version="2.0.45" # -- dscudiero -- 12/16/2016 @ 15:22:46.16
#=======================================================================================================================
# Generic resolve file and call
# Call scriptName ["$scriptArgs"]
# If passed in a full file name for scriptName, then just us it
#=======================================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#=======================================================================================================================
function Call {
		Import FindExecutable InitializeInterpreterRuntime Prompt VerifyPromptVal
		local scriptName="$1"; shift
		local scriptArgs="$*"
		local searchMode useTypes useLibs executeFile executeAlias cmdStr token1
		unset useTypes useLibs executeFile executeAlias cmdStr token1

		## If we were passed in a full file specification then just use it, otherwise find the executable
		if [[ $(dirname $scriptName) == '.' ]]; then
			## Is the token of the form 'xxxx:xx' if so it is a type specification
				searchMode='std'
				token1=$(cut -d ' ' -f1 <<< $scriptArgs)
				if [[ $(Contains ',std,fast,full' ",$token1," ) == true ]]; then
					shift; scriptArgs="$*"
					searchMode="$token1"
				fi

			## Is the token of the form 'xxxx:xx' if so it is a type specification
				local useTypes='search'
				token1=$(cut -d ' ' -f1 <<< $scriptArgs)
				if [[ $(Contains "$token1" ':') == true ]]; then
					shift; scriptArgs="$*"
					useTypes="$token1"
				fi

			## Is the token in the set 'cron,reports,features,patches', if so then it is a lib specification
				local useLibs=''
				token1=$(cut -d ' ' -f1 <<< $scriptArgs)
				if [[ $(Contains ',cron,reports,features,patches,' ",$token1," ) == true ]]; then
					shift; scriptArgs="$*"
					useLibs="$token1"
				fi

			## Find the executable file
				#===========================================================================================================================
				# FindExecutale <callPgmName> <searchMode> [<searchTypes> <searchLibs>
				#	callPgmName	- The name of the program to search for
				#	searchMode	- In the set {'fast','std'}, fast will only search public $TOOLSPATH/src directory
				#	searchTypes	- A comma separated list of Type:extension pairs.  e.g 'Bash:sh,Python:py,Java:class'
				#	srcLibs		- A comma separated list of src subdirectories to search.  In the set {'cron','features','reports','patches'}
				#===========================================================================================================================
				FindExecutable "$scriptName" 'std'  "$useTypes" "$useLibs" ## Sets variable executeFile & executeAlias
		else
			executeFile="$scriptName"
			unset executeAlias
		fi

		## set environment vars overrides
			local myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
			local pgmType="$(cut -d'.' -f2 <<< $(basename $executeFile))"
			[[ $executeAlias != '' ]] && scriptArgs="$executeAlias $scriptArgs"
			local myPath="$(dirname $executeFile)"

		## Call the program
			savePath="$PATH"
			case "$pgmType" in
				py)
					InitializeInterpreterRuntime 'python'
					export PATH="$PYDIR:$PATH"
					cmdStr="$PYDIR/bin/python -u $executeFile $scriptArgs" #$addArgs"
					;;
				java)
					;;
				*)
					cmdStr="source $executeFile $scriptArgs"
					rc=$?
			esac

			[[ $verboseLevel -ge 2 ]] && echo && echo "$cmdStr" && echo && Pause
			local myNameSave="$myName"; local myPathSave="$myPath"
			myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
			myPath="$(dirname $executeFile)"
			($cmdStr) 2>&1 | tee -a $logFile; rc=$?
			myName="$myNameSave" ; myPath="$myPathSave" ; export PATH="$savePath"

	return $rc
} #Call
export -f Call

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
