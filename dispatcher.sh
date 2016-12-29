#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.2.22" # -- dscudiero -- 12/29/2016 @  8:05:24.66
#===================================================================================================
# $callPgmName "$executeFile" ${executeFile##*.} "$libs" $scriptArgs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

dispatcherArgs="$*"
myName='dispatcher'
TOOLSPATH='/steamboat/leepfrog/docs/tools'
[[ -d '/steamboat/leepfrog/docs/toolsNew' ]] && TOOLSPATH='/steamboat/leepfrog/docs/toolsNew'
export DISPATCHER="$TOOLSPATH/dispatcher.sh"

#==================================================================================================
# Global Functions
#==================================================================================================
	function RunMySql {
		local prev resultStr
		prev=$(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
		set -f
		unset resultStr resultSet
		resultStr=$(java runMySql $*)
		[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<<"$resultStr"
		[[ $prev == 'on' ]] && set +f
		return 0
	}
	export -f RunMySql

	function GD {
		[[ $DEBUG != true ]] && return 0
		[[ -z $stdout ]] && stdout=/dev/tty
		[[ $* == 'clear' ]] && echo > $stdout && return 0
		$* >> $stdout
		return 0
	}
	export -f GD

#==================================================================================================
# Local Functions
#==================================================================================================
	function prtStatus {
		[[ $batchMode == true ]] && return 0
		statusLine="${statusLine}${1} $(( $(date "+%s") - $sTime ))s"
		>&3 echo -n -e "${statusLine}\r"
		return 0
	}

#==================================================================================================
# Process the exit from the sourced script
#==================================================================================================
function CleanUp {
	local rc=$1
	GD echo -e "\n=== Dispatcher.Cleanup Starting' =================================================================="
	set +eE
	trap - ERR EXIT

	## Cleanup log file
		if [[ $logFile != /dev/null && -r $logFile ]]; then
			mv $logFile $logFile.bak
		 	#cat $logFile.bak | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | tr -d '\007' > $logFile
		 	cat $logFile.bak | sed "s/\x1B\[[0-9;]*[a-zA-Z]//g" | tr -d '\007' > $logFile
			chmod ug+rwx "$logFile"
		 	rm $logFile.bak
		fi

	## Cleanup semaphore and dblogging
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' && $semaphoreId != "" ]] && Semaphore 'clear' $semaphoreId
		[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'End' $myLogRecordIdx
		SetFileExpansion 'on'
		rm -rf /tmp/$userName.$callPgmName.* > /dev/null 2>&1
		SetFileExpansion

	## Cleanup PATH and CLASSPATH
		[[ $savePath != '' ]] && export PATH="$savePath"
		[[ $saveClasspath != '' ]] && export CLASSPATH="$saveClasspath"

	GD echo -e "\n=== Dispatcher.Cleanup Completed' =================================================================="
	exec 3>&-
	exit $rc
} #CleanUp

#==================================================================================================
# Initialize local variables
#==================================================================================================
unset executeFile
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && calledViaSource=true || calledViaSource=false
sTime=$(date "+%s")
GD='GD echo'; #GD='echo'
statusLine='\tDispatcher: '
## Initialize file descriptor 3 to be stdout unless redirected by caller
	if [[ -t 0 ]]; then # Im running interactive
		if { ! >&3; } 2> /dev/null; then exec 3<> /dev/tty ; fi
	else # Running as a cron job
		exec 3<> /dev/null
	fi

# Who are we
[[ $(which logname 2>&1) != '' ]] && userName=$(logname 2>&1) || userName=$LOGNAME
[[ $userName == 'dscudiero' ]] && userName=$LOGNAME

#==================================================================================================
# Parse arguments
#==================================================================================================
## Initial Checks
	sTime=$(date "+%s")
	[[ "$0" = "-bash" ]] && callPgmName=bashShell || callPgmName=$(basename "$0")
	[[ -z $(getent group leepfrog | grep ','$userName) ]] && \
		echo "*Error* -- User '$userName' is not a member or the 'leepfrog' unix group, please contact the Unix Admin team" && exit -1

	trueDir="$(dirname "$(readlink -f "$0")")"
	$GD "==== Starting $trueDir/dispatcher callPgmName: '$callPgmName' -- $(date) ====";
	[[ -f $(dirname $trueDir)/offline ]] && printf "\n\e[0;31m >>> Sorry, support tools are temporarily off-line, please try again later <<<\n \n\e[m\a"
	[[ -f $(dirname $trueDir)/offline && $userName != $ME ]] && exit
	$GD -e "trueDir = '$trueDir'\nTOOLSPATH = '$TOOLSPATH'"

## Parse off my arguments
	unset scriptArgs myVerbose useLocal semaphoreProcessing noLog noLogInDb batchMode useDevDb myVerbose
	[[ $USELOCAL == true ]] && $useLocal=true
	while [[ $@ != '' ]]; do
		if [[ ${1:0:2} == '--' ]]; then
			myArg=$(echo ${1:2} | tr '[:upper:]' '[:lower:]')
			$GD -e '\t\tmyArg = >'$myArg'<'
			[[ ${myArg:0:1} == 'v' ]] && myVerbose=true
			[[ $myArg == 'uselocal' ]] && useLocal=true
			[[ $myArg == 'nosemaphore' ]] && semaphoreProcessing=false
			[[ $myArg == 'nolog' ]] && noLog=true && noLogInDb=true
			[[ $myArg == 'nologindb' ]] && noLognDb=true
			[[ $myArg == 'batchmode' ]] && batchMode=true && myQuiet=true
			[[ $myArg == 'devdb' || $myArg == 'usedevdb' ]] && useDevDb=true
		else
		 	scriptArgs="$scriptArgs $1"
		fi
		shift
	done
	scriptArgs=${scriptArgs:1} ## Strip off leading blank

## Hello
[[ $batchMode != true && $(hostname) == 'build7.leepfrog.com' ]] && echo -e "\tNote: (dispatcher) The current host has been found to be a bit slow, patience you must have my young padawan" >&3

## If called as ourselves, then the first token is the script name to call
	if [[ $callPgmName == 'dispatcher.sh' ]]; then
		callPgmName=$(cut -d' ' -f1 <<< $scriptArgs)
		[[ $callPgmName == $scriptArgs ]] && unset scriptArgs || scriptArgs=$(cut -d' ' -f2- <<< $scriptArgs)
	fi
	$GD -e "callPgmName = '$callPgmName'\n scriptArgs = '$scriptArgs'"

## Overrides
	[[ ${callPgmName:0:4} == 'test' ]] && noLog=true && noLognDb=true && useLocal=true
	[[ $useLocal == true ]] && export USELOCAL=true

prtStatus "parse args"

#==================================================================================================
# MAIN
#==================================================================================================
## Look for the Initialization and Import function in the library path
	sTime=$(date "+%s")
	unset initFile importFile;
	[[ -z $TOOLSLIBPATH ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"
	for searchDir in $searchDirs; do
		[[ -r ${searchDir}/InitializeRuntime.sh ]] && initFile="${searchDir}/InitializeRuntime.sh"
		[[ -r ${searchDir}/Import.sh ]] && importFile="${searchDir}/Import.sh" && source $importFile
		[[ $initFile != '' && $importFile != '' ]] && break
	done
	#echo "initFile = '$initFile'" ; echo "importFile = '$importFile'"

## Initialize the runtime environment
	$GD "-e \ninitFile = '$initFile'"
	[[ -z $initFile ]] && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1

## Set mysql connection information
	[[ $useDevDb == true ]] && warehouseDb='warehouseDev' || warehouseDb='warehouse'
	dbAcc='Read'
	mySqlUser="leepfrog$dbAcc"
	mySqlHost='duro'
	mySqlPort=3306
	[[ -r "$TOOLSPATH/src/.pw1" ]] && mySqlPw=$(cat "$TOOLSPATH/src/.pw1")
	if [[ $mySqlPw != '' ]]; then
		unset sqlHostIP mySqlConnectString
		sqlHostIP=$(dig +short $mySqlHost.inside.leepfrog.com)
		[[ -z $sqlHostIP ]] && sqlHostIP=$(dig +short $mySqlHost.leepfrog.com)
		[[ -n $sqlHostIP ]] && mySqlConnectString="-h $sqlHostIP -port=$mySqlPort -u $mySqlUser -p$mySqlPw $warehouseDb"
	fi
	[[ -z $mySqlConnectString ]] && echo && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1
	prtStatus ", find initFile"

## Import thins we need to continue
	sTime=$(date "+%s")
	includes='Colors Msg2 Dump Here Quit Contains Lower Upper TitleCase Trim IsNumeric PushSettings PopSettings'
	includes="$includes MkTmpFile Pause ProtectedCall SetFileExpansion PadChar PrintBanner Alert"
	includes="$includes TrapSigs SignalHandeler RunSql DbLog GetCallStack DisplayNews Help"
	includes="$includes GetDefaultsData Call StartRemoteSession FindExecutable CheckRun CheckAuth CheckSemaphore Call"
	Import "$includes"
	#Import FindExecutable CheckRun CheckAuth CheckSemaphore Call
	prtStatus ", imports"

## Source the init script
	sTime=$(date "+%s")
	source $initFile
	prtStatus ", run initFile"

## If sourced then just return
	[[ $calledViaSource == true ]] && return 0

## Resolve the script file to run
	## Were we passed in a fully qualified file name
	if [[ ${callPgmName:0:1} == '/' ]]; then
		executeFile="$callPgmName"
		callPgmName=$(basename $executeFile)
		callPgmName=$(cut -d'.' -f1 <<< $callPgmName)
	else
		sTime=$(date "+%s")
		## Get load data for this script from the scripts table
			unset realCallName lib setSemaphore waitOn
			sqlStmt="select exec,lib,setSemaphore,waitOn from $scriptsTable where name =\"$callPgmName\" "
			RunMySql $sqlStmt
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
	fi ## [[ ${callPgmName:0:1} == '\' ]]
	$GD -e "\n\trealCallName: '$realCallName'\n\tcallPgmName: '$callPgmName'\n\lib: '$lib'\n\tsetSemaphore: '$setSemaphore'\n:\waitOn '$waitOn'"

	## Check to make sure we can run and are authorized
		$GD -e "\tChecking Can we run ..."
		checkMsg=$(CheckRun $callPgmName)
		if [[ $checkMsg != true ]]; then
			[[ $userName != 'dscudiero' ]] && echo && echo && Terminate "$checkMsg"
			[[ $callPgmName != 'testsh' ]] && echo && echo "$(ColorW "*** $checkMsg ***")"
		fi
		$GD -e "\tChecking Auth..."
		checkMsg=$(CheckAuth $callPgmName)
		[[ $checkMsg != true ]] && echo && echo && Terminate "$checkMsg"

	## Check semaphore
		$GD -e "\tChecking Semaphore..."
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' ]] && semaphoreId=$(CheckSemaphore "$callPgmName" "$waitOn")

	## Resolve the executable file
		[[ -z $executeFile ]] && FindExecutable "$callPgmName"  ## Sets variable executeFile
		$GD -e "\n=== Resolved execution file: '$executeFile' ==========================================================="

	## Do we have a viable script
		[[ ! -r $executeFile ]] && echo && echo && Terminate "callPgm.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"

	prtStatus ", find scriptFile"

## Call the script
	## Initialize the log file
		$GD -e "\n\tInitializing logFile..."
		sTime=$(date "+%s")
		logFile=/dev/null
		if [[ $noLog != true ]]; then
			logFile=$logsRoot$callPgmName/$userName--$backupSuffix.log
			if [[ ! -d $(dirname $logFile) ]]; then
				mkdir -p "$(dirname $logFile)"
				chown -R "$userName:leepfrog" "$(dirname $logFile)"
				chmod -R ug+rwx "$(dirname $logFile)"
			fi
			touch "$logFile"
			chmod ug+rwx "$logFile"
			Msg2 "$(PadChar)" > $logFile
			[[ $scriptArgs != '' ]] && scriptArgsTxt=" $scriptArgs" || unset scriptArgsTxt
			Msg2 "$myName:\n^$executeFile\n^$(date)\n^^${callPgmName}${scriptArgsTxt}" >> $logFile
			Msg2 "$(PadChar)" >> $logFile
			Msg2 >> $logFile
			$GD -e "\t logFile: $logFile"
		fi

	## Log Start in process log database
		[[ $noLogInDb != true ]] && myLogRecordIdx=$(dbLog 'Start' "$callPgmName" "$inArgs")

	prtStatus ", initialize logFile"

	## Call program function
		trap "CleanUp" EXIT ## Set trap to return here for cleanup
		$GD -e "\nCall $executeFile $scriptArgs\n"
		myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
		myPath="$(dirname $executeFile)"
		(source $executeFile $scriptArgs) 2>&1 | tee -a $logFile; rc=$?
		rc="$?"

## Should never get here but just in case
	CleanUp $rc

#===================================================================================================
## Check-in log
#===================================================================================================
## Tue Nov 22 07:55:05 CST 2016 - dscudiero - Initial Load
## Thu Dec 22 06:57:50 CST 2016 - dscudiero - Move dispatcher outside of the src folder
## Thu Dec 22 08:03:41 CST 2016 - dscudiero - General syncing of dev to prod
## Thu Dec 22 08:04:37 CST 2016 - dscudiero - General syncing of dev to prod
## Thu Dec 22 09:26:52 CST 2016 - dscudiero - Add status messaging
## Thu Dec 22 09:54:05 CST 2016 - dscudiero - Assign DISPATCHER based on current value of TOOLSPATH
## Thu Dec 22 10:05:50 CST 2016 - dscudiero - Only do the status logging if running interacive
## Tue Dec 27 09:28:42 CST 2016 - dscudiero - Add Help to the pre-loaded functions
## Tue Dec 27 09:39:33 CST 2016 - dscudiero - Do not use Call to call the program, just source the file
## Tue Dec 27 09:53:16 CST 2016 - dscudiero - Tweak messaging
## Tue Dec 27 12:17:50 CST 2016 - dscudiero - Remove message about calling program
## Tue Dec 27 13:54:32 CST 2016 - dscudiero - Tweak messages
## Wed Dec 28 15:21:02 CST 2016 - dscudiero - Added setting of CLASSPATH
## Wed Dec 28 15:31:05 CST 2016 - dscudiero - Added global function RunMySql
## Wed Dec 28 15:58:14 CST 2016 - dscudiero - Update RunMySql function to write out to resultSet array
#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.2.23" # -- dscudiero -- 12/29/2016 @  7:37:24.06
#===================================================================================================
# $callPgmName "$executeFile" ${executeFile##*.} "$libs" $scriptArgs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

dispatcherArgs="$*"
myName='dispatcher'
TOOLSPATH='/steamboat/leepfrog/docs/tools'
[[ -d '/steamboat/leepfrog/docs/toolsNew' ]] && TOOLSPATH='/steamboat/leepfrog/docs/toolsNew'
export DISPATCHER="$TOOLSPATH/dispatcher.sh"

#==================================================================================================
# Global Functions
#==================================================================================================
	function RunMySql {
		local prev resultStr
		prev=$(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
		set -f
		unset resultStr resultSet
		resultStr=$(java runMySql $*)
		[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<<"$resultStr"
		[[ $prev == 'on' ]] && set +f
		return 0
	}
	export -f RunMySql

	function GD {
		[[ $DEBUG != true ]] && return 0
		[[ -z $stdout ]] && stdout=/dev/tty
		[[ $* == 'clear' ]] && echo > $stdout && return 0
		$* >> $stdout
		return 0
	}
	export -f GD

#==================================================================================================
# Local Functions
#==================================================================================================
	function prtStatus {
		[[ $batchMode == true ]] && return 0
		statusLine="${statusLine}${1} $(( $(date "+%s") - $sTime ))s"
		>&3 echo -n -e "${statusLine}\r"
		return 0
	}

#==================================================================================================
# Process the exit from the sourced script
#==================================================================================================
function CleanUp {
	local rc=$1
	GD echo -e "\n=== Dispatcher.Cleanup Starting' =================================================================="
	set +eE
	trap - ERR EXIT

	## Cleanup log file
		if [[ $logFile != /dev/null && -r $logFile ]]; then
			mv $logFile $logFile.bak
		 	#cat $logFile.bak | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | tr -d '\007' > $logFile
		 	cat $logFile.bak | sed "s/\x1B\[[0-9;]*[a-zA-Z]//g" | tr -d '\007' > $logFile
			chmod ug+rwx "$logFile"
		 	rm $logFile.bak
		fi

	## Cleanup semaphore and dblogging
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' && $semaphoreId != "" ]] && Semaphore 'clear' $semaphoreId
		[[ $logInDb != false && $myLogRecordIdx != "" ]] && dbLog 'End' $myLogRecordIdx
		SetFileExpansion 'on'
		rm -rf /tmp/$userName.$callPgmName.* > /dev/null 2>&1
		SetFileExpansion

	## Cleanup PATH and CLASSPATH
		[[ $savePath != '' ]] && export PATH="$savePath"
		[[ $saveClasspath != '' ]] && export CLASSPATH="$saveClasspath"

	GD echo -e "\n=== Dispatcher.Cleanup Completed' =================================================================="
	exec 3>&-
	exit $rc
} #CleanUp

#==================================================================================================
# Initialize local variables
#==================================================================================================
unset executeFile
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && calledViaSource=true || calledViaSource=false
sTime=$(date "+%s")
GD='GD echo'; #GD='echo'
statusLine='\tDispatcher: '
## Initialize file descriptor 3 to be stdout unless redirected by caller
	if [[ -t 0 ]]; then # Im running interactive
		if { ! >&3; } 2> /dev/null; then exec 3<> /dev/tty ; fi
	else # Running as a cron job
		exec 3<> /dev/null
	fi

# Who are we
[[ $(which logname 2>&1) != '' ]] && userName=$(logname 2>&1) || userName=$LOGNAME
[[ $userName == 'dscudiero' ]] && userName=$LOGNAME

#==================================================================================================
# Parse arguments
#==================================================================================================
## Initial Checks
	sTime=$(date "+%s")
	[[ "$0" = "-bash" ]] && callPgmName=bashShell || callPgmName=$(basename "$0")
	[[ -z $(getent group leepfrog | grep ','$userName) ]] && \
		echo "*Error* -- User '$userName' is not a member or the 'leepfrog' unix group, please contact the Unix Admin team" && exit -1

	trueDir="$(dirname "$(readlink -f "$0")")"
	$GD "==== Starting $trueDir/dispatcher callPgmName: '$callPgmName' -- $(date) ====";
	[[ -f $(dirname $trueDir)/offline ]] && printf "\n\e[0;31m >>> Sorry, support tools are temporarily off-line, please try again later <<<\n \n\e[m\a"
	[[ -f $(dirname $trueDir)/offline && $userName != $ME ]] && exit
	$GD -e "trueDir = '$trueDir'\nTOOLSPATH = '$TOOLSPATH'"

## Parse off my arguments
	unset scriptArgs myVerbose useLocal semaphoreProcessing noLog noLogInDb batchMode useDevDb myVerbose
	[[ $USELOCAL == true ]] && $useLocal=true
	while [[ $@ != '' ]]; do
		if [[ ${1:0:2} == '--' ]]; then
			myArg=$(echo ${1:2} | tr '[:upper:]' '[:lower:]')
			$GD -e '\t\tmyArg = >'$myArg'<'
			[[ ${myArg:0:1} == 'v' ]] && myVerbose=true
			[[ $myArg == 'uselocal' ]] && useLocal=true
			[[ $myArg == 'nosemaphore' ]] && semaphoreProcessing=false
			[[ $myArg == 'nolog' ]] && noLog=true && noLogInDb=true
			[[ $myArg == 'nologindb' ]] && noLognDb=true
			[[ $myArg == 'batchmode' ]] && batchMode=true && myQuiet=true
			[[ $myArg == 'devdb' || $myArg == 'usedevdb' ]] && useDevDb=true
		else
		 	scriptArgs="$scriptArgs $1"
		fi
		shift
	done
	scriptArgs=${scriptArgs:1} ## Strip off leading blank

## Hello
[[ $batchMode != true && $(hostname) == 'build7.leepfrog.com' ]] && echo -e "\tNote: (dispatcher) The current host has been found to be a bit slow, patience you must have my young padawan" >&3

## If called as ourselves, then the first token is the script name to call
	if [[ $callPgmName == 'dispatcher.sh' ]]; then
		callPgmName=$(cut -d' ' -f1 <<< $scriptArgs)
		[[ $callPgmName == $scriptArgs ]] && unset scriptArgs || scriptArgs=$(cut -d' ' -f2- <<< $scriptArgs)
	fi
	$GD -e "callPgmName = '$callPgmName'\n scriptArgs = '$scriptArgs'"

## Overrides
	[[ ${callPgmName:0:4} == 'test' ]] && noLog=true && noLognDb=true && useLocal=true
	[[ $useLocal == true ]] && export USELOCAL=true

prtStatus "parse args"

#==================================================================================================
# MAIN
#==================================================================================================
## Look for the Initialization and Import function in the library path
	sTime=$(date "+%s")
	unset initFile importFile;
	[[ -z $TOOLSLIBPATH ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"
	for searchDir in $searchDirs; do
		[[ -r ${searchDir}/InitializeRuntime.sh ]] && initFile="${searchDir}/InitializeRuntime.sh"
		[[ -r ${searchDir}/Import.sh ]] && importFile="${searchDir}/Import.sh" && source $importFile
		[[ $initFile != '' && $importFile != '' ]] && break
	done
	#echo "initFile = '$initFile'" ; echo "importFile = '$importFile'"

## Initialize the runtime environment
	$GD "-e \ninitFile = '$initFile'"
	[[ -z $initFile ]] && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1

## Set mysql connection information
	[[ $useDevDb == true ]] && warehouseDb='warehouseDev' || warehouseDb='warehouse'
	dbAcc='Read'
	mySqlUser="leepfrog$dbAcc"
	mySqlHost='duro'
	mySqlPort=3306
	[[ -r "$TOOLSPATH/src/.pw1" ]] && mySqlPw=$(cat "$TOOLSPATH/src/.pw1")
	if [[ $mySqlPw != '' ]]; then
		unset sqlHostIP mySqlConnectString
		sqlHostIP=$(dig +short $mySqlHost.inside.leepfrog.com)
		[[ -z $sqlHostIP ]] && sqlHostIP=$(dig +short $mySqlHost.leepfrog.com)
		[[ -n $sqlHostIP ]] && mySqlConnectString="-h $sqlHostIP -port=$mySqlPort -u $mySqlUser -p$mySqlPw $warehouseDb"
	fi
	[[ -z $mySqlConnectString ]] && echo && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1
	prtStatus ", find initFile"

## Import thins we need to continue
	sTime=$(date "+%s")
	includes='Colors Msg2 Dump Here Quit Contains Lower Upper TitleCase Trim IsNumeric PushSettings PopSettings'
	includes="$includes MkTmpFile Pause ProtectedCall SetFileExpansion PadChar PrintBanner Alert"
	includes="$includes TrapSigs SignalHandeler RunSql DbLog GetCallStack DisplayNews Help"
	includes="$includes GetDefaultsData Call StartRemoteSession FindExecutable CheckRun CheckAuth CheckSemaphore Call"
	Import "$includes"
	#Import FindExecutable CheckRun CheckAuth CheckSemaphore Call
	prtStatus ", imports"

## Source the init script
	sTime=$(date "+%s")
	source $initFile
	prtStatus ", run initFile"

## If sourced then just return
	[[ $calledViaSource == true ]] && return 0

## Resolve the script file to run
	## Were we passed in a fully qualified file name
	if [[ ${callPgmName:0:1} == '/' ]]; then
		executeFile="$callPgmName"
		callPgmName=$(basename $executeFile)
		callPgmName=$(cut -d'.' -f1 <<< $callPgmName)
	else
		sTime=$(date "+%s")
		## Get load data for this script from the scripts table
			unset realCallName lib setSemaphore waitOn
			sqlStmt="select exec,lib,setSemaphore,waitOn from $scriptsTable where name =\"$callPgmName\" "
RunSql $sqlStmt
resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString")
dump resultString
unset resultString


			RunMySql $sqlStmt

resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString")
dump resultString
unset resultString

Pause

			if [[ ${#resultSet[0]} -gt 0 ]]; then
			 	resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString")
				realCallName="$(cut -d'|' -f1 <<< "$resultString")"
				lib="$(cut -d'|' -f2 <<< "$resultString")"; [[ $(Upper "$lib") == 'NULL' ]] && lib="src"
				setSemaphore="$(cut -d'|' -f3 <<< "$resultString")"; [[ $(Upper "$setSemaphore") == 'NULL' ]] && unset setSemaphore
				waitOn="$(cut -d'|' -f4 <<< "$resultString")"; [[ $(Upper "$waitOn") == 'NULL' ]] && unset waitOn
				if [[ $realCallName != '' && $(Upper "$realCallName") != 'NULL' ]]; then
					callPgmName="$(cut -d' ' -f1 <<< "$realCallName")"
					callArgs="$(cut -d' ' -f2- <<< "$realCallName")"
					[[ $callArgs != '' ]] && scriptArgs="$callArgs $scriptArgs"
				fi
			fi
	fi ## [[ ${callPgmName:0:1} == '\' ]]
	$GD -e "\n\trealCallName: '$realCallName'\n\tcallPgmName: '$callPgmName'\n\lib: '$lib'\n\tsetSemaphore: '$setSemaphore'\n:\waitOn '$waitOn'"

	## Check to make sure we can run and are authorized
		$GD -e "\tChecking Can we run ..."
		checkMsg=$(CheckRun $callPgmName)
		if [[ $checkMsg != true ]]; then
			[[ $userName != 'dscudiero' ]] && echo && echo && Terminate "$checkMsg"
			[[ $callPgmName != 'testsh' ]] && echo && echo "$(ColorW "*** $checkMsg ***")"
		fi
		$GD -e "\tChecking Auth..."
		checkMsg=$(CheckAuth $callPgmName)
		[[ $checkMsg != true ]] && echo && echo && Terminate "$checkMsg"

	## Check semaphore
		$GD -e "\tChecking Semaphore..."
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' ]] && semaphoreId=$(CheckSemaphore "$callPgmName" "$waitOn")

	## Resolve the executable file
		[[ -z $executeFile ]] && FindExecutable "$callPgmName"  ## Sets variable executeFile
		$GD -e "\n=== Resolved execution file: '$executeFile' ==========================================================="

	## Do we have a viable script
		[[ ! -r $executeFile ]] && echo && echo && Terminate "callPgm.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"

	prtStatus ", find scriptFile"

## Call the script
	## Initialize the log file
		$GD -e "\n\tInitializing logFile..."
		sTime=$(date "+%s")
		logFile=/dev/null
		if [[ $noLog != true ]]; then
			logFile=$logsRoot$callPgmName/$userName--$backupSuffix.log
			if [[ ! -d $(dirname $logFile) ]]; then
				mkdir -p "$(dirname $logFile)"
				chown -R "$userName:leepfrog" "$(dirname $logFile)"
				chmod -R ug+rwx "$(dirname $logFile)"
			fi
			touch "$logFile"
			chmod ug+rwx "$logFile"
			Msg2 "$(PadChar)" > $logFile
			[[ $scriptArgs != '' ]] && scriptArgsTxt=" $scriptArgs" || unset scriptArgsTxt
			Msg2 "$myName:\n^$executeFile\n^$(date)\n^^${callPgmName}${scriptArgsTxt}" >> $logFile
			Msg2 "$(PadChar)" >> $logFile
			Msg2 >> $logFile
			$GD -e "\t logFile: $logFile"
		fi

	## Log Start in process log database
		[[ $noLogInDb != true ]] && myLogRecordIdx=$(dbLog 'Start' "$callPgmName" "$inArgs")

	prtStatus ", initialize logFile"

	## Call program function
		trap "CleanUp" EXIT ## Set trap to return here for cleanup
		$GD -e "\nCall $executeFile $scriptArgs\n"
		myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
		myPath="$(dirname $executeFile)"
		(source $executeFile $scriptArgs) 2>&1 | tee -a $logFile; rc=$?
		rc="$?"

## Should never get here but just in case
	CleanUp $rc

#===================================================================================================
## Check-in log
#===================================================================================================
## Tue Nov 22 07:55:05 CST 2016 - dscudiero - Initial Load
## Thu Dec 22 06:57:50 CST 2016 - dscudiero - Move dispatcher outside of the src folder
## Thu Dec 22 08:03:41 CST 2016 - dscudiero - General syncing of dev to prod
## Thu Dec 22 08:04:37 CST 2016 - dscudiero - General syncing of dev to prod
## Thu Dec 22 09:26:52 CST 2016 - dscudiero - Add status messaging
## Thu Dec 22 09:54:05 CST 2016 - dscudiero - Assign DISPATCHER based on current value of TOOLSPATH
## Thu Dec 22 10:05:50 CST 2016 - dscudiero - Only do the status logging if running interacive
## Tue Dec 27 09:28:42 CST 2016 - dscudiero - Add Help to the pre-loaded functions
## Tue Dec 27 09:39:33 CST 2016 - dscudiero - Do not use Call to call the program, just source the file
## Tue Dec 27 09:53:16 CST 2016 - dscudiero - Tweak messaging
## Tue Dec 27 12:17:50 CST 2016 - dscudiero - Remove message about calling program
## Tue Dec 27 13:54:32 CST 2016 - dscudiero - Tweak messages
## Wed Dec 28 15:21:02 CST 2016 - dscudiero - Added setting of CLASSPATH
## Wed Dec 28 15:31:05 CST 2016 - dscudiero - Added global function RunMySql
## Wed Dec 28 15:58:14 CST 2016 - dscudiero - Update RunMySql function to write out to resultSet array
## Thu Dec 29 08:07:14 CST 2016 - dscudiero - Switch to use java RunMySql
