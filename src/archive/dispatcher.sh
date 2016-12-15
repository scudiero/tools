#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.0.66" # -- dscudiero -- 11/22/2016 @  9:14:17.00
#===================================================================================================
# $callPgmName "$executeFile" ${executeFile##*.} "$libs" $scriptArgs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

dispatcherArgs="$*"
myName='dispatcher'

#==================================================================================================
# Global debug routine
#==================================================================================================
function GD {
	[[ $DEBUG != true ]] && return 0
	[[ $stdout == '' ]] && stdout=/dev/tty
	[[ $* == 'clear' ]] && echo > $stdout && return 0
	$* >> $stdout
	return 0
}
export -f GD
[[ $(logname) == 'dscudiero' ]] && GD 'clear'

#==================================================================================================
# Process the exit from the sourced script
#==================================================================================================
function CleanUp {
	local rc=$1
	GD echo -e "\n=== Dispatcher.Cleanup Starting' =================================================================="
	set +eE
	trap - ERR EXIT

	## Cleanup log file
		if [[ $logFile != /dev/null ]]; then
			mv $logFile $logFile.bak
		 	cat $logFile.bak | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" > $logFile
			chmod ug+rwx "$logFile"
		 	rm $logFile.bak
		fi

	## Cleanup semaphore and dblogging
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' && $semaphoreId != "" ]] && Semaphore 'clear' $semaphoreId
		[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'End' $myLogRecordIdx
		SetFileExpansion 'on'
		rm -rf /tmp/$LOGNAME.$exName.* > /dev/null 2>&1
		SetFileExpansion

	GD echo -e "\n=== Dispatcher.Cleanup Completed' =================================================================="
	exit $rc
} #CleanUp

#==================================================================================================
# Initialize local variables
#==================================================================================================
TOOLSPATH='/steamboat/leepfrog/docs/tools'
searchMode='fast'
overRideSearchMode=true;
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && calledViaSource=true || calledViaSource=false
GD='GD echo'
#GD='echo'

#==================================================================================================
# Parse arguments
#==================================================================================================
## Initial Checks
	sTime=$(date "+%s")
	[[ "$0" = "-bash" ]] && callPgmName=bashShell || callPgmName=$(basename "$0")
	[[ $(getent group leepfrog | grep ','$(logname)) == '' ]] && \
		echo "*Error* -- User '$(logname)' is not a member or the 'leepfrog' unix group, please contact the Unix Admin team" && exit -1

	trueDir="$(dirname "$(readlink -f "$0")")"
	$GD "==== Starting $trueDir/dispatcher callPgmName: '$callPgmName' ====";
	[[ -f $(dirname $trueDir)/offline ]] && printf "\n\e[0;31m >>> Sorry, support tools are temporarially offline, please try again later <<<\n \n\e[m\a"
	[[ -f $(dirname $trueDir)/offline && $LOGNAME != $ME ]] && exit
	$GD -e "trueDir = '$trueDir'\nTOOLSPATH = '$TOOLSPATH'"

## Parse off my arguments
	unset scriptArgs myVerbose useLocal semaphoreProcessing noLog noLogInDb batchMode
	while [[ $@ != '' ]]; do
		if [[ ${1:0:2} == '--' ]]; then
			myArg=$(echo ${1:2} | tr '[:upper:]' '[:lower:]')
			$GD -e '\t\tmyArg = >'$myArg'<'
			[[ $myArg == 'v' ]] && verboseLevel=3
			[[ $myArg == 'uselocal' ]] && useLocal=true
			[[ $myArg == 'nosemaphore' ]] && semaphoreProcessing=false
			[[ $myArg == 'nolog' ]] && noLog=true && noLogInDb=true
			[[ $myArg == 'nologindb' ]] && noLognDb=true
			[[ $myArg == 'batchmode' ]] && batchMode=true
			[[ $myArg == 'fast' ]] && overRideSearchMode=false
		else
		 	scriptArgs="$scriptArgs $1"
		fi
		shift
	done
	scriptArgs=${scriptArgs:1} ## Strip off leading blank

## If called as ourselves, then the first token is the script name to call
	if [[ $callPgmName == 'dispatcher.sh' ]]; then
		callPgmName=$(cut -d' ' -f1 <<< $scriptArgs)
		[[ $callPgmName == $scriptArgs ]] && unset scriptArgs || scriptArgs=$(cut -d' ' -f2- <<< $scriptArgs)
	fi
	$GD -e "callPgmName = '$callPgmName'\n scriptArgs = '$scriptArgs'"

## Overrides
	[[ ${callPgmName:0:4} == 'test' ]] && noLog=true && noLognDb=true && useLocal=true && searchMode='full'
	[[ $(logname) == 'dscudiero' && $overRideSearchMode == true ]] && searchMode='full'
	[[ $UseLocal == true ]] && useLocal=true

$GD "Time (s) to parse arguments: $(( $(date "+%s") - $sTime ))"

#==================================================================================================
# MAIN
#==================================================================================================
## Load the library files (*.sh)
	sTime=$(date "+%s")
	lookForFile="InitializeRuntime.sh"; unset initFile;
	[[ $TOOLSLIBPATH == '' ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"
	for searchDir in $searchDirs; do
	    $GD "searchDir = '$searchDir'"
	    [[ ! -d $searchDir ]] && continue
		for file in $(ls $searchDir/*.sh 2>/dev/null); do
			$GD -e "\tfile = '$file'"
			[[ $(basename $file) == 'InitializeRuntime.sh' ]] && initFile="$file" && continue
			source $file
		done;
	done

## Initialize the runtime environment
	$GD "initFile = '$initFile'"
	[[ $initFile == '' ]] && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1

## Set mysql connection information
	[[ $warehouseDb == '' ]] && warehouseDb='warehouse'
	dbAcc='Read'
	mySqlUser="leepfrog$dbAcc"
	mySqlHost='duro'
	mySqlPort=3306
	[[ -r "$TOOLSPATH/src/.pw1" ]] && mySqlPw=$(cat "$TOOLSPATH/src/.pw1")
	if [[ $mySqlPw != '' ]]; then
		unset sqlHostIP mySqlConnectString
		sqlHostIP=$(dig +short $mySqlHost.inside.leepfrog.com)
		[[ $sqlHostIP == '' ]] && sqlHostIP=$(dig +short $mySqlHost.leepfrog.com)
		[[ $sqlHostIP != '' ]] && mySqlConnectString="-h $sqlHostIP -port=$mySqlPort -u $mySqlUser -p$mySqlPw $warehouseDb"
	fi
	[[ $mySqlConnectString == '' ]] && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1

	$GD "Time (s) to find initFile: $(( $(date "+%s") - $sTime ))"

## Source the init script
	sTime=$(date "+%s")
	source $initFile
	$GD "Time (s) to run initFile: $(( $(date "+%s") - $sTime ))"

## If sourced then just return
	[[ $calledViaSource == true ]] && return 0

## Find the script file to run
	sTime=$(date "+%s")

	## Get load data for this script from the scripts table
		unset realCallName lib setSemaphore waitOn
		sqlStmt="select exec,lib,setSemaphore,waitOn from $scriptsTable where name =\"$callPgmName\" "
		RunSql $sqlStmt
		if [[ ${#resultSet[0]} -gt 0 ]]; then
		 	resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString")
			realCallName="$(cut -d'|' -f1 <<< "$resultString")"
			lib="$(cut -d'|' -f2 <<< "$resultString")"; [[ $lib == 'NULL' ]] && lib="src"
			setSemaphore="$(cut -d'|' -f3 <<< "$resultString")"; [[ $setSemaphore == 'NULL' ]] && unset setSemaphore
			waitOn="$(cut -d'|' -f4 <<< "$resultString")"; [[ $waitOn == 'NULL' ]] && unset waitOn
			if [[ $realCallName != '' && $realCallName != 'NULL' ]]; then
				callPgmName="$(cut -d' ' -f1 <<< "$realCallName")"
				callArgs="$(cut -d' ' -f2- <<< "$realCallName")"
				[[ $callArgs != '' ]] && scriptArgs="$callArgs $scriptArgs"
			fi
		fi
		$GD -e "\trealCallName: '$realCallName'\n\tcallPgmName: '$callPgmName'\n\lib: '$lib'\n\tsetSemaphore: '$setSemaphore'\n:\waitOn '$waitOn'"

	## Check to make sure we can run and are authorized
		$GD -e "\tChecking Can we run ..."
		checkMsg=$(CheckRun $callPgmName)
		if [[ $checkMsg != true ]]; then
			[[ $LOGNAME != 'dscudiero' ]] && Msg2 && Msg2 $T "$checkMsg"
			[[ $exName != 'testsh' ]] && Msg2 "$(ColorW "*** $checkMsg ***")"
		fi
		$GD -e "\tChecking Auth..."
		checkMsg=$(CheckAuth $callPgmName)
		[[ $checkMsg != true ]] && Msg2 && Msg2 "$checkMsg" && Msg2 && Goodbye 'quiet'

	## Check semaphore
		$GD -e "\tChecking Semaphore..."
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' ]] && semaphoreId=$(CheckSemaphore "$callPgmName" "$waitOn")

	## Resolve the executable file
		FindExecutable "$callPgmName"  ## Sets variable executeFile
		$GD -e "\n=== Resolved execution file: '$executeFile' ==========================================================="

	## Do we have a viable script
		[[ ! -r $executeFile ]] && Msg2 $T "callPgm.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"

	$GD "Time (s) to find scriptFile: $(( $(date "+%s") - $sTime ))"

## Call the script

	sTime=$(date "+%s")

	## Initialize the log file
		$GD -e "\tInitializing logFile..."
		logFile=/dev/null
		if [[ $noLog != true ]]; then
			logFile=$logsRoot$exName/$userName--$backupSuffix.log
			if [[ ! -d $(dirname $logFile) ]]; then
				mkdir -p "$(dirname $logFile)"
				chown -R "$userName:leepfrog" "$(dirname $logFile)"
				chmod -R ug+rwx "$(dirname $logFile)"
			fi
			touch "$logFile"
			chmod ug+rwx "$logFile"
			Msg2 "\n$executeFile\n\t$(date)\n\t$callPgmName $scriptArgs" > $logFile
			Msg2 "$(PadChar)" >> $logFile
			$GD -e "\t logFile: $logFile"
		fi

	## Log Start in process log database
		[[ $noLogInDb != true ]] && myLogRecordIdx=$(dbLog 'Start' "$exName" "$inArgs")

	$GD "Time (s) to initialize logFile: $(( $(date "+%s") - $sTime ))"

	## Call program function
		trap "CleanUp" EXIT ## Set trap to return here for cleanup
		$GD -e "\nCall $executeFile $scriptArgs\n"
		Call "$executeFile" $scriptArgs
		rc=$?

## Should never get here but just in case
	CleanUp $rc

#===================================================================================================
## Check-in log
#===================================================================================================
## Tue Nov 22 07:55:05 CST 2016 - dscudiero - Initial Load
