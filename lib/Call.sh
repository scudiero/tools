#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="2.1.6" # -- dscudiero -- Thu 06/08/2017 @ 16:34:03.02
#=======================================================================================================================
# Generic resolve file and call
# Call scriptName ["$scriptArgs"]
# If passed in a full file name for scriptName, then just us it
# scriptArgs parsed as follows:
# 1) if first token = 'fork' then fork off the subshell task
# 2) if first token is in the set {std,fast,full} then it is a searchMode specification (e.g. python:py)
# 3) if first token of the form 'xxxx:xx' then it is a useTypes specification (e.g. python:py)
# 4) if first token is in the set {cron,reports,features,patches,java} (from dispatcher.scriptData2) then it is a useLibs
#	specification
#=======================================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#=======================================================================================================================
function Call {
		Import 'FindExecutable' 'InitializeInterpreterRuntime' 'Prompt' 'VerifyPromptVal' 'Semaphore'
		local scriptName="$1"; shift
		local fork utility useTypes scriptArgs executeFile executeAlias cmdStr searchMode='std'

		pushd "$TOOLSPATH/src" >& /dev/null
		SetFileExpansion 'on'
		useLibs=$(ls  -d */ | tr -d '/' | tr $"\n" ',')
		SetFileExpansion
		popd >& /dev/null
		until [[ -z $* ]]; do
			[[ $1 == 'fork' ]] && fork=true && shift && continue
			[[ $1 == 'utility' ]] && utility=true && shift && continue
			[[ $1 == 'std' || $1 == 'fast' || $1 == 'full'  ]] && searchMode="$1" && shift && continue
			[[ $(Contains "$1" ':') == true ]] && useTypes="$1" && shift && continue
			[[ $(Contains ",$useLibs," ",$1,") == true && $1 != 'reports' ]] && shift && continue
			scriptArgs="$scriptArgs $1"
			shift || true
		done
		dump -2 scriptName scriptArgs fork utility searchMode useTypes useLibs

		## Resolve the executable file
		if [[ $(dirname $scriptName) == '.' ]]; then
			## Search for the executable file
				#===========================================================================================================================
				# FindExecutale <callPgmName> <searchMode> [<searchTypes> <searchLibs>
				#	callPgmName	- The name of the program to search for
				#	searchMode	- In the set {'fast','std'}, fast will only search public $TOOLSPATH/src directory
				#	searchTypes	- A comma separated list of Type:extension pairs.  e.g 'Bash:sh,Python:py,Java:class'
				#	srcLibs		- A comma separated list of src subdirectories to search.  In the set {'cron','features','reports','patches'}
				#===========================================================================================================================
				FindExecutable "$scriptName" 'std' "$useTypes" "$useLibs" ## Sets variable executeFile & executeAlias
				#dump executeFile executeAlias
		else
			## If we were passed in a full file specification then just use it
			executeFile="$scriptName"
			unset executeAlias
		fi

		## set environment vars overrides
			local myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
			local pgmType="$(cut -d'.' -f2 <<< $(basename $executeFile))"
			[[ -n $executeAlias ]] && scriptArgs="$executeAlias $scriptArgs"
			local myPath="$(dirname $executeFile)"

		## Check to make sure we can run
			checkMsg=$(CheckRun $myName)
			if [[ $checkMsg != true ]]; then
				[[ $(Contains ",$administrators," ",$userName,") != true ]] && echo && echo && Terminate "$checkMsg"
				[[ $myName != 'testsh' ]] && echo && echo -e "\t$(ColorW "*** $checkMsg ***")"
			fi

		## Check to make sure we are authorized
			checkMsg=$(CheckAuth $myName)
			[[ $checkMsg != true ]] && echo && echo && Terminate "$checkMsg"

		## Call the program
			savePath="$PATH"
			case "$pgmType" in
				py)
					InitializeInterpreterRuntime 'python'
					export PATH="$PYDIR:$PATH"
					cmdStr="$PYDIR/bin/python -u $executeFile" #$addArgs"
					;;
				java)
					setFileExpansion 'off'
					cmdStr="java $scriptName"
					setFileExpansion
					;;
				*)
					cmdStr="source $executeFile"
			esac

			local myNameSave="$myName"; local myPathSave="$myPath"
			myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
			myPath="$(dirname $executeFile)"
			#[[ $utility == true ]] && ($cmdStr) 2>&1 || ($cmdStr) 2>&1 | tee -a $logFile

			[[ $verboseLevel -ge 2 ]] && echo && echo "$cmdStr" "$scriptArgs" && echo && Pause
			if [[ $fork == true ]]; then
				($cmdStr $scriptArgs) 2>&1 &
				rc=$?
			else
				($cmdStr $scriptArgs) 2>&1
				rc=$?
			fi
			[[ -n $semaphoreId ]] && Semaphore 'clear' $semaphoreId
			myName="$myNameSave" ; myPath="$myPathSave" ;
			export PATH="$savePath"

	return $rc
} #Call
export -f Call

#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Wed Dec 28 15:46:17 CST 2016 - dscudiero - Pull the valid library types from the database
## Tue Jan  3 11:56:53 CST 2017 - dscudiero - Ad 'utility' option to not tee results of call to stdout
## Tue Jan  3 15:21:33 CST 2017 - dscudiero - Removed extra execution of cmdstr
## Tue Jan  3 16:34:10 CST 2017 - dscudiero - remove io redirection from the actual call
## Wed Jan  4 13:52:54 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 07:59:46 CST 2017 - dscudiero - Added 'fork' directive
## Fri Jan  6 08:03:52 CST 2017 - dscudiero - Also parse for 'fork' if a full file name is passed in
## Tue Feb 14 11:38:03 CST 2017 - dscudiero - Add semaphore processing
## Tue Mar 14 13:20:01 CDT 2017 - dscudiero - return the condition code after the call
## 04-14-2017 @ 13.01.43 - ("2.0.77")  - dscudiero - remove subshell on call
## 04-28-2017 @ 16.41.53 - ("2.0.78")  - dscudiero - run command in a subshell
## 05-12-2017 @ 13.16.49 - ("2.0.81")  - dscudiero - cleanup
## 05-12-2017 @ 15.05.09 - ("2.0.82")  - dscudiero - Comment out semaphore stuff
## 05-17-2017 @ 13.40.55 - ("2.0.83")  - dscudiero - Force add 'reports' to the list of librarys to search
## 05-18-2017 @ 12.02.45 - ("2.1.1")   - dscudiero - Refactored parameter parsing
## 05-19-2017 @ 07.21.18 - ("2.1.5")   - dscudiero - Ignore 'reports' if passed in as an argument
## 06-08-2017 @ 16.34.25 - ("2.1.6")   - dscudiero - Add back the auth and run checks
