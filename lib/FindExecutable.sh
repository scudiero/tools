#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="1.2.53" # -- dscudiero -- Tue 05/08/2018 @ 14:38:30.96
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
	## Defaults ====================================================================================
	local mode='source' fileName='' token type ext found=false searchTokens checkFile searchRoot=''
	local useLocal=$USELOCAL useDev=$USEDEV runScript=false scriptArgs=''

	## Parse arguments =============================================================================
	while [[ $# -gt 0 ]]; do
 	    [[ $1 =~ ^-file|--filename$ ]] && { fileName="$2"; shift 2 || true; continue; }
	    [[ $1 =~ ^-m|--mode$ ]] && { mode="$2"; shift 2 || true; continue; }
	    [[ $1 =~ ^-sr|-so|-sh|--src$|--source$ ]] && { mode='src'; shift 1 || true; continue; }
	    [[ $1 =~ ^-l|--lib$ ]] && { mode='lib'; shift 1 || true; continue; }
	    [[ $1 =~ ^-py|--python$ ]] && { mode='python'; searchRoot="${mode}"; shift 1 || true; continue; }
	    [[ $1 =~ ^-cp|--cpp$ ]] && { mode='cpp'; searchRoot="${mode}"; shift 1 || true; continue; }
	    [[ $1 =~ ^-cr|--cron$ ]] && { mode='cron'; searchRoot="${mode}"; shift 1 || true; continue; }
	    [[ $1 =~ ^-j|--java$ ]] && { mode='java'; searchRoot="${mode}"; shift 1 || true; continue; }

	    [[ $1 =~ ^-pa|--patch$ ]] && { mode='patch'; searchRoot="${mode}es"; shift 1 || true; continue; }
	    [[ $1 =~ ^-fe|--feature$ ]] && { mode='feature'; searchRoot="${mode}s"; shift 1 || true; continue; }
	    [[ $1 =~ ^-st|--step$ ]] && { mode='step'; searchRoot="${mode}s"; shift 1 || true; continue; }
	    [[ $1 =~ ^-re|--report$ ]] && { mode='report'; searchRoot="${mode}s"; shift 1 || true; continue; }
	    [[ $1 =~ ^-ru|--run$ ]] && { runScript=true; shift 1 || true; continue; }
	    [[ $1 =~ ^-uselocal|--uselocal$ ]] && { useLocal=true; shift 1 || true; continue; }
	    [[ $1 =~ ^-usedev|--usedev$ ]] && { useDev=true; shift 1 || true; continue; }
	    [[ -z $fileName && ${1:0:1} != '-' ]] && fileName="$1" || scriptArgs="$scriptArgs $1"
	    shift 1 || true
	done

	## Search for the file
	if [[ $mode == 'lib' ]]; then
 		searchDirs="$TOOLSPATH/lib"
		[[ $useDev == true && -n $TOOLSDEVPATH && -d "$TOOLSDEVPATH/lib" ]] && searchDirs="$TOOLSDEVPATH/lib $searchDirs"
		[[ $useLocal == true && -d "$HOME/tools/lib" ]] && searchDirs="$HOME/tools/lib $searchDirs"
		searchTokens="bash:sh cpp:cpp"
	else
		searchDirs="$TOOLSPATH/src"
		[[ $useDev == true && -n $TOOLSDEVPATH && -d "$TOOLSDEVPATH/src" ]] && searchDirs="$TOOLSDEVPATH/src $searchDirs"
		[[ $useLocal == true && -d "$HOME/tools/src" ]] && searchDirs="$HOME/tools/src $searchDirs"
		searchTokens="bash:sh python:py java:class steps:html report:sh cron:sh"
	fi
Dump -t fileName mode searchRoot searchTokens searchDirs scriptArgs > $stdout

	## Search for the file based in the searchDirs based on the searchTokens
	for dir in $searchDirs; do
Dump -t dir >> $stdout
		for token in $(tr ',' ' ' <<< "$searchTokens"); do
			type="${token%%:*}"; ext="${token##*:}"
Dump -t2 type ext >> $stdout
			[[ -n $searchRoot ]] && checkFile="$dir/$searchRoot/${fileName}.${ext}" || checkFile="$dir/${fileName}.${ext}"
Dump -t3 checkFile >> $stdout
			[[ -r "$checkFile" ]] && { found=true; break; } || unset checkFile
		done
		[[ $found == true ]] && break
	done

	executeFile="$checkFile" 
Dump -t executeFile >> $stdout

	if [[ $runScript == true ]]; then
		#Dump -t scriptArgs
		[[ -z "$executeFile" || ! -r "$executeFile" ]] && Terminate "$FUNCNAME: Run options active and could not find execution file, fileName='$fileName'"
		myNameSave="$myName"; myPathSave="$myPath"
		myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
		myPath="$(dirname $executeFile)"
		source "$executeFile" $scriptArgs || echo "$executeFile"
		myName="$myNameSave"; myPath="$myPathSave"
	else
		[[ -z "$executeFile" ]] && return 0
		[[ ! -r "$executeFile" ]] && unset executeFile && return 0
		echo "$executeFile"
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
## 06-02-2017 @ 15.19.07 - ("1.0.125") - dscudiero - Refactor setting of the search path for local and dev
## 06-09-2017 @ 08.13.33 - ("1.0.126") - dscudiero - add debug code
## 06-09-2017 @ 08.17.34 - ("1.0.127") - dscudiero - General syncing of dev to prod
## 06-09-2017 @ 08.19.10 - ("1.0.128") - dscudiero - remove debug statements
## 09-29-2017 @ 10.13.30 - ("1.2.0")   - dscudiero - Refactored for performance
## 09-29-2017 @ 13.03.09 - ("1.2.3")   - dscudiero - remove debug code
## 10-02-2017 @ 11.37.34 - ("1.2.20")  - dscudiero - Add -python, -java, -cpp
## 10-02-2017 @ 12.36.17 - ("1.2.21")  - dscudiero - General syncing of dev to prod
## 10-11-2017 @ 07.30.52 - ("1.2.23")  - dscudiero - Added -run option
## 10-11-2017 @ 07.31.46 - ("1.2.24")  - dscudiero - Cosmetic/minor change
## 10-13-2017 @ 14.36.46 - ("1.2.28")  - dscudiero - Add debug stuff
## 10-13-2017 @ 14.40.35 - ("1.2.29")  - dscudiero - remove debug stuff
## 10-16-2017 @ 12.50.59 - ("1.2.30")  - dscudiero - Fix problem resolving -cron files
## 10-16-2017 @ 12.54.54 - ("1.2.31")  - dscudiero - Throw an error run is active and cannot find execution file
## 10-16-2017 @ 13.10.49 - ("1.2.32")  - dscudiero - Add -sh flag
## 10-18-2017 @ 13.48.16 - ("1.2.33")  - dscudiero - Set myName and myPath if running a the found file
## 10-23-2017 @ 07.56.04 - ("1.2.34")  - dscudiero - change the min abbreviation for file to be -file
## 10-27-2017 @ 13.28.25 - ("1.2.47")  - dscudiero - Cosmetic/minor change
## 04-18-2018 @ 09:34:45 - 1.2.49 - dscudiero - Refactored setting searchdirs
