#!/bin/bash
#==================================================================================================
version=1.1.15 # -- dscudiero -- 12/14/2016 @ 11:29:43.64
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Refresh a single file in a courseleaf site"

#= Description +===================================================================================
# Refresh a single file in a courseleaf site
#==================================================================================================
minFrameworkVer=6
#= Change Log =====================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# xx-xx-16 -- dgs - Initial coding
#==================================================================================================
# Standard initial checks and setup
	[[ $(type -t GetFrameworkVersion) != 'function' ]] && printf "\n\e[0;31m*Error* -- Sorry cannot execute this script, the tools framework has not been loaded\e[m\a\n\n" && exit -1
	frameworkVersion=$(GetFrameworkVersion)
	if [[ ${frameworkVersion:0:1} -lt $minFrameworkVer ]]; then
		printf "\n*Error* -- This script requires a minimum framework version of '$minFrameworkVer.00', current version is '$frameworkVersion'\n*** Stopping ***\n\n"
		trap - EXIT QUIT; exit -1
	fi
	originalArgStr="$*"

#==================================================================================================
# Standard call back functions
#==================================================================================================
	function parseArgs-refreshCourseleafFile  {
		argList+=(-file,4,option,file,,script,'The file name relative to the root site directory')
		return 0
	}
	function Goodbye-refreshCourseleafFile  {
		return 0
	}
	function testMode-refreshCourseleafFile  {
		return 0
	}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs'
tgtDir=$srcDir
srcDir=$skeletonRoot/release

# get file

	[[ $verify == true && $file != '' && ! -f ${srcDir}${file} ]] && Msg2 "Could not locate source file: ${srcDir}${file}" && unset file
	while [[ $file == '' ]]; do
		Prompt file "What file do you wish to refresh from the skeletion/release\n\t(file relative to the site root directory)"
		[[ ! -f ${srcDir}${file} ]] && Msg2 "^Could not locate source file: ${srcDir}${file}" && unset file
	done

# set full filenames
	srcFile=${srcDir}${file}
	tgtFile=${tgtDir}${file}
	[[ ! -f $srcFile ]] && Msg2 && Msg2 $T "Could not locate source file:\n^'$srcFile'" && unset file
	[[ ! -f $tgtFile ]] && Msg2 && Msg2 $W "Could not locate target file:\n^'$tgtFile'"

## Verify continue
	unset verifyArgs
	verifyArgs+=("Client:$client")
	verifyArgs+=("Target Env:$(TitleCase $env)")
	verifyArgs+=("Source File:$srcFile")
	verifyArgs+=("Target File:$tgtFile")
	VerifyContinue "You are asking to refresh a courseleaf file:"

## Copy file if changed
	result=$(CopyFileWithCheck "$srcFile" "$tgtFile" 'backup')
	if [[ $result == true ]]; then
		changeLogRecs+=("Updated: $file from skeleton")
		WriteChangelogEntry 'changeLogRecs' "$tgtDir/changelog.txt"
		Msg2 "^'$file' copied"
	elif [[ $result == 'same' ]]; then
		Msg2 "^File md5's match, no changes made"
	else
		Msg2 $T "Error copying file:\n^$result"
	fi
#==================================================================================================
## Done
#==================================================================================================
Goodbye 0 #'alert'

#==================================================================================================
## Check-in log
#==================================================================================================
# 01-08-2016 -- dscudiero -- Refresh a single courseleaf file from the skeleton/release (1.1.0)
## Fri Apr 29 12:02:37 CDT 2016 - dscudiero - Refactored
## Fri Apr 29 12:52:23 CDT 2016 - dscudiero - Teaked log message
