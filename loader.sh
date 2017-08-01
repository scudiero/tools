#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.3.24" # -- dscudiero -- Tue 08/01/2017 @ 13:05:40.78
#===================================================================================================
# $callPgmName "$executeFile" ${executeFile##*.} "$libs" $scriptArgs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
loaderArgs="$*"
myName='loader'

#==================================================================================================
# Local Functions
#==================================================================================================
	function prtStatus {
		#[[ $batchMode == true || $myVerbose != true ]] && return 0
		[[ $batchMode == true ]] && return 0
		local elapTime=$(( $(date "+%s") - $sTime ))
		[[ $elapTime -eq 0 ]] && elapTime=1
		statusLine="${statusLine}${1}: ${elapTime}s"
		>&3 echo -n -e "${statusLine}\r"
		return 0
	}

#==================================================================================================
# Process the exit from the sourced script
#==================================================================================================
function CleanUp {
	local rc=$1
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
		[[ -n $semaphoreId ]] && Semaphore 'clear' $semaphoreId
		[[ $logInDb != false && -n $myLogRecordIdx ]] && ProcessLogger 'End' $myLogRecordIdx
		SetFileExpansion 'on'
		[[ -f "$tmpFile*" ]] && rm -f "$tmpFile"
		SetFileExpansion

	## Cleanup PATH and CLASSPATH
		[[ -n $savePath ]] && export PATH="$savePath"
		[[ -n $saveClasspath ]] && export CLASSPATH="$saveClasspath"

	exec 3>&-  ## Close file descriptor #3 -
	exit $rc
} #CleanUp

#==================================================================================================
# Initialize local variables
#==================================================================================================
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && calledViaSource=true || calledViaSource=false
sTime=$(date "+%s")
statusLine="Loader ($version): "
## Initialize file descriptor 3 to be stdout unless redirected by caller
	if [[ -t 0 ]]; then # Im running interactive
		if { ! >&3; } 2> /dev/null; then exec 3<> /dev/tty ; fi
	else # Running as a cron job
		exec 3<> /dev/null
	fi

# Who is the logged in user
	userName=$(/usr/bin/logname 2>&1)
	[[ -z $userName && -n $LOGNAME ]] && userName=$LOGNAME
	[[ $userName == 'dscudiero' ]] && userName=$LOGNAME

## Set tmpRoot directory
	tmpRoot=/tmp/$LOGNAME
	[[ ! -d $tmpRoot ]] && mkdir -p $tmpRoot

#==================================================================================================
# Parse arguments
#==================================================================================================
## Initial Checks
	[[ -z $TOOLSPATH ]] && echo -e "\n*Error* -- The TOOLSPATH environment value has not been set, cannot continue\n" && exit -3

	sTime=$(date "+%s")
	if [[ "$0" != "-bash" ]]; then
		callPgmName=$(basename "$1")
		shift
	else
		callPgmName='bashShell'
	fi

	leepUsers="$(getent group leepfrog)"
	leepUsers=",${leepUsers##*:},"
	grep -q ",$userName," <<< "$leepUsers" ; rc=$?
	[[ $rc -ne 0 ]] && echo "*Error* -- User '$userName' is not a member or the 'leepfrog' unix group, please contact the Unix Admin team" && exit -1

	trueDir="$(dirname "$(readlink -f "$0")")"
	[[ -f $(dirname $trueDir)/offline ]] && printf "\n\e[0;31m >>> Sorry, support tools are temporarily off-line, please try again later <<<\n \n\e[m\a"
	[[ -f $(dirname $trueDir)/offline && $userName != $ME ]] && exit

## Parse off my arguments
	unset scriptArgs myVerbose useDev useLocal noLog noLogInDb batchMode useDevDb myVerbose myQuiet viaCron
	[[ $USELOCAL == true ]] && useLocal=true
	while [[ -n $@ ]]; do
		if [[ ${1:0:2} == '--' ]]; then
			myArg=$(echo ${1:2} | tr '[:upper:]' '[:lower:]')
			[[ ${myArg:0:1} == 'v' ]] && myVerbose=true
			[[ $myArg == 'usedev' ]] && useDev=true
			[[ $myArg == 'uselocal' ]] && useLocal=true
			[[ $myArg == 'nolog' ]] && noLog=true && noLogInDb=true
			[[ $myArg == 'nologindb' ]] && noLognDb=true
			[[ $myArg == 'batchmode' ]] && batchMode=true && myQuiet=true
			[[ $myArg == 'devdb' || $myArg == 'usedevdb' ]] && useDevDb=true
			[[ $myArg == 'quiet' ]] && myQuiet=true
			[[ $myArg == 'viacron' ]] && viaCron=true
		else
		 	scriptArgs="$scriptArgs $1"
		fi
		shift
	done
	export USELOCAL=$useLocal
	scriptArgs=${scriptArgs:1} ## Strip off leading blank

## Hello
[[ $batchMode != true && $(hostname) == 'build7.leepfrog.com' ]] && \
	echo -e "\tNote: (loader) File system access from the current host has been found to be a bit slow,\n\tPatience you must have my young padawan..." >&3

## If called as ourselves, then the first token is the script name to call
	if [[ $callPgmName == 'loader.sh' ]]; then
		callPgmName=$(cut -d' ' -f1 <<< $scriptArgs)
		[[ $callPgmName == $scriptArgs ]] && unset scriptArgs || scriptArgs=$(cut -d' ' -f2- <<< $scriptArgs)
	fi

## Overrides
	[[ ${callPgmName:0:4} == 'test' ]] && noLog=true && noLogInDb=true && useLocal=true
	[[ $useLocal == true ]] && export USELOCAL=true
	if [[ $useDev == true ]]; then
		export USEDEV=true 
		[[ $userName != 'dscudiero' ]] && echo "*Warning* -- ($myName) Using the tools development directories"
	fi

prtStatus "parse args"
sTime=$(date "+%s")

#==================================================================================================
# MAIN
#==================================================================================================
## Set the CLASSPATH
	sTime=$(date "+%s")
	saveClasspath="$CLASSPATH"
	searchDirs="$TOOLSPATH/src"
	[[ $USEDEV == true && -d "$TOOLSDEVPATH/src" ]] && searchDirs="$TOOLSDEVPATH/src"
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
	[[ $USEDEV == true && -d "$TOOLSDEVPATH/lib" ]] && searchDirs="$TOOLSDEVPATH/lib"
	for searchDir in $searchDirs; do
		[[ -r ${searchDir}/InitializeRuntime.sh ]] && initFile="${searchDir}/InitializeRuntime.sh"
		[[ -r ${searchDir}/Import.sh ]] && importFile="${searchDir}/Import.sh" && source $importFile
		[[ -n $initFile && -n $importFile ]] && break
	done

## Initialize the runtime environment
	[[ -z $initFile ]] && echo "*Error* -- ($myName) Sorry, no 'InitializeRuntime' file found in the library directories" && exit -1

## Import thins we need to continue
	sTime=$(date "+%s")
	includes='StringFunctions Msg2 Dump Here Quit PushSettings PopSettings MkTmpFile Pause ProtectedCall'
	includes="$includes SetFileExpansion PadChar PrintBanner Alert TrapSigs SignalHandeler RunSql2 Prompt VerifyPromptVal"
	includes="$includes DbLog ProcessLogger GetCallStack DisplayNews Help Call StartRemoteSession FindExecutable"
	includes="$includes CheckRun CheckAuth GetDefaultsData Call ParseArgs ParseArgsStd Hello Init Goodbye"
	Import "$includes"
	prtStatus ", imports"
	sTime=$(date "+%s")

## Source the init script
	TrapSigs 'on'
	source $initFile
	prtStatus ", load initFile"
	sTime=$(date "+%s")

## If sourced then just return
	[[ $viaCron == true ]] && return 0

## Resolve the script file to run
	## Were we passed in a fully qualified file name
	if [[ ${callPgmName:0:1} == '/' ]]; then
		executeFile="$callPgmName"
		callPgmName=$(basename $executeFile)
		callPgmName=$(cut -d'.' -f1 <<< $callPgmName)
	fi ## [[ ${callPgmName:0:1} == '\' ]]
	## Check to make sure we can run
		checkMsg=$(CheckRun $callPgmName)
		if [[ $checkMsg != true ]]; then
			[[ $(Contains ",$administrators," ",$userName,") != true ]] && echo && echo && Terminate "$checkMsg"
			[[ $callPgmName != 'testsh' ]] && echo && echo -e "$(ColorW "*** $checkMsg ***")"
		fi
	## Check to make sure we are authorized
		checkMsg=$(CheckAuth $callPgmName)
		[[ $checkMsg != true ]] && echo && echo && Terminate "$checkMsg"

		prtStatus ", check run"
		sTime=$(date "+%s")

	## Check semaphore
		[[ $(Contains ",$setSemaphoreList," ",$callPgmName," ) == true ]] && semaphoreId=$(CheckSemaphore "$callPgmName" "$waitOn")

	## Resolve the executable file
		[[ -z $executeFile ]] && FindExecutable "$callPgmName"  ## Sets variable executeFile
		prtStatus ", find file"
		sTime=$(date "+%s")
	## Do we have a viable script
		[[ ! -r $executeFile ]] && echo && echo && Terminate "callPgm.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"

## Call the script
	## Initialize the log file
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
			chown "$userName:leepfrog" "$logFile"
			Msg2 "$(PadChar)" > $logFile
			[[ -n $scriptArgs ]] && scriptArgsTxt=" $scriptArgs" || unset scriptArgsTxt
			Msg2 "$myName:\n^$executeFile\n^$(date)\n^^${callPgmName}${scriptArgsTxt}" >> $logFile
			Msg2 "$(PadChar)" >> $logFile
			Msg2 >> $logFile
		fi

	prtStatus ", logFile"
	sTime=$(date "+%s")

	## Call program function
		myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
		myPath="$(dirname $executeFile)"
		#(source $executeFile $scriptArgs) 2>&1 | tee -a $logFile; rc=$?
		prtStatus ", calling"
		[[ $batchMode != true && $myQuiet != true ]] && echo
		TrapSigs 'off'
		trap "CleanUp" EXIT ## Set trap to return here for cleanup
		[[ $(cut -d' ' -f1 <<< $(wc -l "$executeFile")) -eq 0 ]] && Terminate "Execution file ($executeFile) is empty"
		source $executeFile $scriptArgs 2>&1 | tee -a $logFile; rc=$?

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
## 03-31-2017 @ 07.29.34 - ("1.2.89")  - dscudiero - reformat debug stuff
## 03-31-2017 @ 08.06.56 - ("1.2.90")  - dscudiero - Remove debug statements
## 04-05-2017 @ 13.46.35 - ("1.2.91")  - dscudiero - Make sure TOOLSPATH has a value
## 04-11-2017 @ 07.08.37 - ("1.2.98")  - dscudiero - Impliment the boot process
## 04-12-2017 @ 15.28.05 - ("1.2.99")  - dscudiero - fix spelling errors
## 04-13-2017 @ 12.02.10 - ("1.2.100") - dscudiero - Fix spelling error
## 04-14-2017 @ 12.49.09 - ("1.2.103") - dscudiero - do not create a subshell when sourceing script
## 04-17-2017 @ 07.41.20 - ("1.2.105") - dscudiero - remove import fpr dump array, moved code to the Dump file
## 05-02-2017 @ 10.34.00 - ("1.2.110") - dscudiero - Add checks to make sure TOOLSPATH is set
## 05-02-2017 @ 10.38.21 - ("1.2.111") - dscudiero - General syncing of dev to prod
## 05-04-2017 @ 11.20.48 - ("1.2.112") - dscudiero - Add useDev flag
## 05-05-2017 @ 08.41.58 - ("1.2.114") - dscudiero - Add additional verbose status statements
## 05-05-2017 @ 08.45.26 - ("1.2.115") - dscudiero - tweak messaging
## 05-10-2017 @ 09.42.55 - ("1.2.124") - dscudiero - General syncing of dev to prod
## 05-10-2017 @ 09.45.37 - ("1.2.126") - dscudiero - General syncing of dev to prod
## 05-10-2017 @ 12.48.48 - ("1.2.127") - dscudiero - Turn off traps before script call
## 05-10-2017 @ 12.55.26 - ("1.2.128") - dscudiero - Removed the GD function
## 05-10-2017 @ 12.58.59 - ("1.2.130") - dscudiero - removed extra GD calls
## 05-12-2017 @ 14.19.21 - ("1.2.131") - dscudiero - x
## 05-12-2017 @ 14.41.31 - ("1.2.132") - dscudiero - clean out commented code
## 05-12-2017 @ 14.46.21 - ("1.2.133") - dscudiero - General syncing of dev to prod
## 05-12-2017 @ 14.48.37 - ("1.2.134") - dscudiero - 1
## 05-12-2017 @ 14.58.05 - ("1.2.136") - dscudiero - misc changes to speed up
## 05-12-2017 @ 15.05.20 - ("1.2.137") - dscudiero - tweak comments
## 05-15-2017 @ 10.25.07 - ("1.2.138") - dscudiero - Set TOOLSPATH if not already set
## 05-16-2017 @ 06.43.27 - ("1.2.139") - dscudiero - Make sure that the tmpRoot directory exists
## 05-17-2017 @ 10.49.38 - ("1.2.140") - dscudiero - export USELOCAL
## 05-18-2017 @ 07.34.06 - ("1.2.141") - dscudiero - Delete all files matching tmpFile in cleanup
## 05-19-2017 @ 15.50.00 - ("1.2.142") - dscudiero - Remove includes that are not needed any longer (CheckSemaphore & IsNumeric)
## 05-26-2017 @ 10.31.51 - ("1.2.160") - dscudiero - Added --useDev support
## 06-02-2017 @ 15.20.58 - ("1.2.176") - dscudiero - Move bootdata load to dispatcher
## 06-08-2017 @ 08.32.56 - ("1.2.176") - dscudiero - Added --viaCron flag
## 06-08-2017 @ 09.10.57 - ("1.2.176") - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 09.12.53 - ("1.3.0")   - dscudiero - Turn on status messaging
## 06-08-2017 @ 12.48.49 - ("1.3.1")   - dscudiero - Fix problem with run check and offline scripts
## 06-08-2017 @ 14.13.11 - ("1.3.2")   - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 14.23.50 - ("1.3.3")   - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 16.35.36 - ("1.3.4")   - dscudiero - tweak messaging
## 06-12-2017 @ 11.15.37 - ("1.3.5")   - dscudiero - add debug statements
## 06-12-2017 @ 11.16.56 - ("1.3.6")   - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.24.10 - ("1.3.7")   - dscudiero - remove debug statements
## 06-13-2017 @ 08.48.40 - ("1.3.8")   - dscudiero - Tweak how userName is set
## 06-14-2017 @ 08.08.20 - ("1.3.15")  - dscudiero - Remove debug statements
## 06-14-2017 @ 09.54.08 - ("1.3.21")  - dscudiero - Strip off first token as the toCall program name
## 06-19-2017 @ 07.06.50 - ("1.3.21")  - dscudiero - tweak formatting
## 07-31-2017 @ 16.43.25 - ("1.3.22")  - dscudiero - Set the group for the log file to leepfrog
## 08-01-2017 @ 10.57.18 - ("1.3.23")  - dscudiero - reformat messages
## 08-01-2017 @ 13.21.58 - ("1.3.24")  - dscudiero - Tweak messages
