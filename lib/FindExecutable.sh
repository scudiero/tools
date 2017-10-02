#!/bin/bash
## XO NOT AUTOVERSION
#=======================================================================================================================
# version="1.2.21" # -- dscudiero -- Mon 10/02/2017 @ 12:00:21.66
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
	#Import 'Dump,Msg3'; Verbose 3 -l "$FUNCNAME: Starting"
	## Defaults ====================================================================================
	local mode='source' file='' token type ext found=false searchTokens checkFile searchRoot=''
	local useLocal=$USELOCAL useDev=$USEDEV
	## Parse arguments =============================================================================
	while [[ $# -gt 0 ]]; do
	    [[ $1 =~ ^-fi|--file$ ]] && { file="$2"; shift 2; continue; }
	    [[ $1 =~ ^-m|--mode$ ]] && { mode="$2"; shift 2; continue; }
	    [[ $1 =~ ^-sr|-so|--src$|--source$ ]] && { mode='src'; shift 1; continue; }
	    [[ $1 =~ ^-l|--lib$ ]] && { mode='lib'; shift 1; continue; }
	    [[ $1 =~ ^-py|--python$ ]] && { mode='python'; searchRoot="${mode}"; shift 1; continue; }
	    [[ $1 =~ ^-cp|--cpp$ ]] && { mode='cpp'; searchRoot="${mode}"; shift 1; continue; }
	    [[ $1 =~ ^-cr|--cron$ ]] && { mode='cron'; searchRoot="${mode}"; shift 1; continue; }
	    [[ $1 =~ ^-j|--java$ ]] && { mode='java'; searchRoot="${mode}"; shift 1; continue; }

	    [[ $1 =~ ^-pa|--patch$ ]] && { mode='patch'; searchRoot="${mode}s"; shift 1; continue; }
	    [[ $1 =~ ^-fe|--feature$ ]] && { mode='feature'; searchRoot="${mode}s"; shift 1; continue; }
	    [[ $1 =~ ^-st|--step$ ]] && { mode='step'; searchRoot="${mode}s"; shift 1; continue; }
	    [[ $1 =~ ^-r|--report$ ]] && { mode='report'; searchRoot="${mode}s"; shift 1; continue; }
	    [[ -z $file ]] && file="$1"
	    shift 1 || true
	done

	## Search for the file
	if [[ $mode != 'lib' ]]; then
		[[ -n $TOOLSSRCPATH ]] && searchDirs="$(tr ':' ' ' <<< $TOOLSSRCPATH)" || searchDirs="$TOOLSPATH/src"
		[[ $useDev == true && -n $TOOLSDEVPATH && -d "$TOOLSDEVPATH/src" ]] && searchDirs="$TOOLSDEVPATH/src $searchDirs"
		[[ $useLocal == true && -d "$HOME/tools/src" ]] && searchDirs="$HOME/tools/src $searchDirs"
		searchTokens="bash:sh python:py java:class steps:html report:sh"
	else
		[[ -n $TOOLSLIBPATH ]] && searchDirs="$(tr ':' ' ' <<< $TOOLSLIBPATH)" || searchDirs="$TOOLSPATH/lib"
		[[ $useDev == true && -n $TOOLSDEVPATH && -d "$TOOLSDEVPATH/lib" ]] && searchDirs="$TOOLSDEVPATH/lib $searchDirs"
		[[ $useLocal == true && -d "$HOME/tools/lib" ]] && searchDirs="$HOME/tools/lib $searchDirs"
		searchTokens="bash:sh cpp:cpp"
	fi
	#Dump -t file mode searchRoot searchTokens -n

	for dir in $searchDirs; do
		#Dump -t dir
		for token in $(tr ',' ' ' <<< "$searchTokens"); do
			type="${token%%:*}"; ext="${token##*:}"
			#Dump -t2 type ext
			[[ -n $searchRoot ]] && checkFile="$dir/$searchRoot/${file}.${ext}" || checkFile="$dir/${file}.${ext}"
			#Dump -t3 checkFile
			[[ -r "$checkFile" ]] && { found=true; break; } || unset checkFile
		done
		[[ $found == true ]] && break
	done
	#Verbose "$FUNCNAME: Ending"
	echo "$checkFile"
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
