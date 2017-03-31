#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.2.88" # -- dscudiero -- Fri 03/31/2017 @  7:20:05.47
#===================================================================================================
# $callPgmName "$executeFile" ${executeFile##*.} "$libs" $scriptArgs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
dispatcherArgs="$*"
myName='dispatcher'
echo "Starting $myName"

[[ -d "$(dirname "$TOOLSPATH")/toolsNew" ]] && TOOLSPATH="$(dirname "$TOOLSPATH")/toolsNew"
[[ -z $DISPATCHER ]] && export DISPATCHER="$TOOLSPATH/dispatcher.sh"
[[ -n $TOOLSWAREHOUSEDB ]] && warehouseDb="$TOOLSWAREHOUSEDB" || warehouseDb='warehouse'
export TOOLSWAREHOUSEDB="$warehouseDb"

echo
echo "\$0 = '$0'"
echo "TOOLSWAREHOUSEDB = '$TOOLSWAREHOUSEDB'"
echo

#==================================================================================================
# Global Functions
#==================================================================================================
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
		[[ $batchMode == true || $myVerbose != true ]] && return 0
		local elapTime=$(( $(date "+%s") - $sTime ))
		[[ $elapTime -eq 0 ]] && elapTime=1
		statusLine="${statusLine}${1} ${elapTime}s"
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
		[[ $semaphoreProcessing == true && $(Lower $setSemaphore) == 'yes' && -n $semaphoreId ]] && Semaphore 'clear' $semaphoreId
		[[ $logInDb != false && -n $myLogRecordIdx ]] && ProcessLogger 'End' $myLogRecordIdx
		SetFileExpansion 'on'
		[[ -f "$tmpFile" ]] && rm -f "$tmpFile"
		SetFileExpansion

	## Cleanup PATH and CLASSPATH
		[[ -n $savePath ]] && export PATH="$savePath"
		[[ -n $saveClasspath ]] && export CLASSPATH="$saveClasspath"

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
statusLine="\tDispatcher ($version): "
## Initialize file descriptor 3 to be stdout unless redirected by caller
	if [[ -t 0 ]]; then # Im running interactive
		if { ! >&3; } 2> /dev/null; then exec 3<> /dev/tty ; fi
	else # Running as a cron job
		exec 3<> /dev/null
	fi

# Who is the logged in user
[[ -n $(which logname 2>&1) ]] && userName=$(logname 2>&1) || userName=$LOGNAME
[[ $userName == 'dscudiero' ]] && userName=$LOGNAME
tmpRoot=/tmp/$LOGNAME

#==================================================================================================
# Parse arguments
#==================================================================================================
## Initial Checks
	sTime=$(date "+%s")
	[[ "$0" = "-bash" ]] && callPgmName=bashShell || callPgmName=$(basename "$0")

	leepUsers="$(getent group leepfrog)"
	leepUsers=",${leepUsers##*:},"
	grep -q ",$userName," <<< "$leepUsers" ; rc=$?
	[[ $rc -ne 0 ]] && echo "*Error* -- User '$userName' is not a member or the 'leepfrog' unix group, please contact the Unix Admin team" && exit -1

	trueDir="$(dirname "$(readlink -f "$0")")"
	$GD "==== Starting $trueDir/dispatcher callPgmName: '$callPgmName' -- $(date) ====";
	[[ -f $(dirname $trueDir)/offline ]] && printf "\n\e[0;31m >>> Sorry, support tools are temporarily off-line, please try again later <<<\n \n\e[m\a"
	[[ -f $(dirname $trueDir)/offline && $userName != $ME ]] && exit
	$GD -e "trueDir = '$trueDir'\nTOOLSPATH = '$TOOLSPATH'"

## Parse off my arguments
	unset scriptArgs myVerbose useLocal semaphoreProcessing noLog noLogInDb batchMode useDevDb myVerbose myQuiet
	[[ $USELOCAL == true ]] && $useLocal=true
	while [[ -n $@ ]]; do
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
			[[ $myArg == 'quiet' ]] && myQuiet=true
		else
		 	scriptArgs="$scriptArgs $1"
		fi
		shift
	done
	scriptArgs=${scriptArgs:1} ## Strip off leading blank

## Hello
[[ $batchMode != true && $(hostname) == 'build7.leepfrog.com' ]] && \
	echo -e "\tNote: (dispatcher) Fild system access from the current host has been found to be a bit slow,\n\tPatience you must have my young padawan..." >&3

## If called as ourselves, then the first token is the script name to call
	if [[ $callPgmName == 'dispatcher.sh' ]]; then
		callPgmName=$(cut -d' ' -f1 <<< $scriptArgs)
		[[ $callPgmName == $scriptArgs ]] && unset scriptArgs || scriptArgs=$(cut -d' ' -f2- <<< $scriptArgs)
	fi
	$GD -e "callPgmName = '$callPgmName'\n scriptArgs = '$scriptArgs'"

## Overrides
	[[ ${callPgmName:0:4} == 'test' ]] && noLog=true && noLogInDb=true && useLocal=true
	[[ $useLocal == true ]] && export USELOCAL=true

prtStatus "parse args"

#==================================================================================================
# MAIN
#==================================================================================================

## Set the CLASSPATH
	sTime=$(date "+%s")
	saveClasspath="$CLASSPATH"
	searchDirs="$TOOLSPATH/src"
	[[ -n $TOOLSSRCPATH ]] && searchDirs="$( tr ':' ' ' <<< $TOOLSSRCPATH)"
	unset CLASSPATH
	for searchDir in $searchDirs; do
		for jar in $(find $searchDir/java -mindepth 1 -maxdepth 1 -type f -name \*.jar); do
			[[ -z $CLASSPATH ]] && CLASSPATH="$jar" || CLASSPATH="$CLASSPATH:$jar"
		done
	done
	export CLASSPATH="$CLASSPATH"

## Look for the Initialization and Import function in the library path
	sTime=$(date "+%s")
	unset initFile importFile;
	[[ -z $TOOLSLIBPATH ]] && searchDirs="$TOOLSPATH/lib" || searchDirs="$( tr ':' ' ' <<< $TOOLSLIBPATH)"
	for searchDir in $searchDirs; do
		[[ -r ${searchDir}/InitializeRuntime.sh ]] && initFile="${searchDir}/InitializeRuntime.sh"
		[[ -r ${searchDir}/Import.sh ]] && importFile="${searchDir}/Import.sh" && source $importFile
		[[ -n $initFile && -n $importFile ]] && break
	done
	#echo "initFile = '$initFile'" ; echo "importFile = '$importFile'"

## Initialize the runtime environment
	$GD "-e \ninitFile = '$initFile'"
	[[ -z $initFile ]] && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1

## Set mysql connection information
	# dbAcc='Read'
	# mySqlUser="leepfrog$dbAcc"
	# mySqlHost='duro'
	# mySqlPort=3306
	# [[ -r "$TOOLSPATH/src/.pw1" ]] && mySqlPw=$(cat "$TOOLSPATH/src/.pw1")
	# if [[ -n $mySqlPw ]]; then
	# 	unset sqlHostIP mySqlConnectString
	# 	sqlHostIP=$(dig +short $mySqlHost.inside.leepfrog.com)
	# 	[[ -z $sqlHostIP ]] && sqlHostIP=$(dig +short $mySqlHost.leepfrog.com)
	# 	[[ -n $sqlHostIP ]] && mySqlConnectString="-h $sqlHostIP -port=$mySqlPort -u $mySqlUser -p$mySqlPw $warehouseDb"
	# fi
	# [[ -z $mySqlConnectString ]] && echo && echo "*Error* -- ($myName) Sorry, Insufficient information to set 'mySqlConnectString'" && exit -1
	# prtStatus ", find initFile"

## Import thins we need to continue
	sTime=$(date "+%s")
	includes='StringFunctions Msg2 Dump DumpArray Here Quit PushSettings PopSettings MkTmpFile Pause ProtectedCall'
	includes="$includes SetFileExpansion PadChar PrintBanner Alert TrapSigs SignalHandeler RunSql RunSql2"
	includes="$includes DbLog ProcessLogger GetCallStack DisplayNews Help Call StartRemoteSession FindExecutable"
	includes="$includes CheckRun CheckAuth CheckSemaphore GetDefaultsData Call ParseArgs ParseArgsStd Hello Init Goodbye"
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
			RunSql2 $sqlStmt
			if [[ ${#resultSet[0]} -gt 0 ]]; then
			 	resultString=${resultSet[0]}; resultString=$(tr "\t" "|" <<< "$resultString")
				realCallName="$(cut -d'|' -f1 <<< "$resultString")"
				lib="$(cut -d'|' -f2 <<< "$resultString")"; [[ $lib == 'NULL' ]] && lib="src"
				setSemaphore="$(cut -d'|' -f3 <<< "$resultString")"; [[ $setSemaphore == 'NULL' ]] && unset setSemaphore
				waitOn="$(cut -d'|' -f4 <<< "$resultString")"; [[ $waitOn == 'NULL' ]] && unset waitOn
				if [[ -n $realCallName && $realCallName != 'NULL' ]]; then
					callPgmName="$(cut -d' ' -f1 <<< "$realCallName")"
					callArgs="$(cut -d' ' -f2- <<< "$realCallName")"
					[[ -n $callArgs ]] && scriptArgs="$callArgs $scriptArgs"
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
			[[ -n $scriptArgs ]] && scriptArgsTxt=" $scriptArgs" || unset scriptArgsTxt
			Msg2 "$myName:\n^$executeFile\n^$(date)\n^^${callPgmName}${scriptArgsTxt}" >> $logFile
			Msg2 "$(PadChar)" >> $logFile
			Msg2 >> $logFile
			$GD -e "\t logFile: $logFile"
		fi

	prtStatus ", initialize logFile"

	## Call program function
		[[ $batchMode != true && $myQuiet != true ]] && echo
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
## Thu Dec 29 10:14:36 CST 2016 - dscudiero - Add RunSqlite function
## Thu Dec 29 15:57:02 CST 2016 - dscudiero - Added quick return in RunMySql and RunSqlite if DOIT is off
## Tue Jan  3 07:34:27 CST 2017 - dscudiero - Add DumpArray to imports list
## Tue Jan  3 07:42:45 CST 2017 - dscudiero - add version to the status message
## Tue Jan  3 10:27:03 CST 2017 - dscudiero - add Quiet option to disable status messaging
## Tue Jan  3 12:32:29 CST 2017 - dscudiero - use myQuiet for my variable name
## Tue Jan  3 16:29:41 CST 2017 - dscudiero - add status messaging back in
## Thu Jan  5 11:04:42 CST 2017 - dscudiero - Updated to use RunSql2
## Thu Jan  5 12:00:50 CST 2017 - dscudiero - Updated code to set warehouseDb
## Thu Jan  5 12:06:21 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 12:23:20 CST 2017 - dscudiero - Check for DISPATCHER variable before setting
## Thu Jan  5 15:02:07 CST 2017 - dscudiero - remove RunMySql and RunSqlite
## Thu Jan  5 16:15:23 CST 2017 - dscudiero - if status time is zero, display 1
## Fri Jan  6 16:40:40 CST 2017 - dscudiero - Switch to use ProcessLogger
## Wed Jan 11 07:54:19 CST 2017 - dscudiero - Set noLogInDb if module is test*
## Wed Jan 11 11:04:43 CST 2017 - dscudiero - Removed functions now in StrinFunctions
## Wed Jan 11 11:31:58 CST 2017 - dscudiero - Remove import for Contains
## Wed Jan 11 11:40:41 CST 2017 - dscudiero - Cleaned up imports
## Thu Jan 12 14:31:55 CST 2017 - dscudiero - Turn off loading messages
## Thu Jan 12 14:34:51 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan 13 07:20:02 CST 2017 - dscudiero - Misc cleanup
## Fri Jan 13 15:25:28 CST 2017 - dscudiero - Move setting of classpath in from init
## Wed Jan 18 15:00:06 CST 2017 - dscudiero - add debug code
## Thu Jan 19 07:13:30 CST 2017 - dscudiero - Add debug statement
## Mon Feb  6 09:29:28 CST 2017 - dscudiero - Set tmpRoot
## Mon Feb  6 10:32:37 CST 2017 - dscudiero - Update logic for checking if user is in the leepfrog group
## Mon Feb  6 10:36:05 CST 2017 - dscudiero - set tmpFile
## 03-24-2017 @ 10.26.08 - ("1.2.63")  - dscudiero - Only remove the current tmpFile, not all for the called pgm
## 03-30-2017 @ 07.34.29 - ("1.2.64")  - dscudiero - weak messaging
## 03-30-2017 @ 08.07.05 - ("1.2.65")  - dscudiero - Tweak buil7 is slow message
## 03-30-2017 @ 12.17.16 - ("1.2.66")  - dscudiero - Update the code where WAREHOUSEDB overrides the default value
## 03-30-2017 @ 12.59.09 - ("1.2.71")  - dscudiero - add debug messages
## 03-30-2017 @ 13.01.48 - ("1.2.72")  - dscudiero - Remove debug Statements
## 03-30-2017 @ 13.15.59 - ("1.2.73")  - dscudiero - Add debug statements
## 03-30-2017 @ 13.25.50 - ("1.2.75")  - dscudiero - General syncing of dev to prod
## 03-30-2017 @ 13.27.27 - ("1.2.76")  - dscudiero - General syncing of dev to prod
## 03-30-2017 @ 13.30.46 - ("1.2.78")  - dscudiero - General syncing of dev to prod
## 03-30-2017 @ 13.31.33 - ("1.2.79")  - dscudiero - General syncing of dev to prod
## 03-30-2017 @ 14.02.03 - ("1.2.80")  - dscudiero - Remove debug statements
## 03-30-2017 @ 14.41.01 - ("1.2.81")  - dscudiero - Make sure TOOLSWAREHOUSEDB is set
## 03-30-2017 @ 14.49.38 - ("1.2.82")  - dscudiero - Add debug messages
## 03-30-2017 @ 15.11.07 - ("1.2.83")  - dscudiero - Backout last change
## 03-31-2017 @ 07.01.14 - ("1.2.84")  - dscudiero - only read bootdata if it is me
## 03-31-2017 @ 07.02.23 - ("1.2.85")  - dscudiero - General syncing of dev to prod
## 03-31-2017 @ 07.14.23 - ("1.2.86")  - dscudiero - General syncing of dev to prod
## 03-31-2017 @ 07.17.42 - ("1.2.87")  - dscudiero - General syncing of dev to prod
## 03-31-2017 @ 07.20.10 - ("1.2.88")  - dscudiero - General syncing of dev to prod
## Fri Mar 31 07:24:00 CDT 2017 - dscudiero - -m Sync
