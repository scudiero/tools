#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="1.6.31" # -- dscudiero -- Fri 06/07/2019 @ 14:25:25
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
loaderArgs="$*"
myName='loader'
[[ $(/usr/bin/logname 2>&1) == $me && $DEBUG == true ]] && echo -e "\n*** In $myName ($version)\n\t\$* = >$*<"

#==================================================================================================
# Process the exit from the sourced script
#==================================================================================================
function CleanUp {
	local rc=$1
	set +eE
	trap - ERR EXIT
	## Cleanup log file
		if [[ $logFile != '/dev/null'  && -f $logFile ]]; then
			if [[ -e $logFile ]]; then
				mv $logFile $logFile.bak
			 	#cat $logFile.bak | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[mGK]//g" | tr -d '\007' > $logFile
			 	cat $logFile.bak | sed "s/\x1B\[[0-9;]*[a-zA-Z]//g" | tr -d '\007' > $logFile
				chown -R "$userName:leepfrog" "$logFile"
				chmod 660 "$logFile"
			 	rm $logFile.bak
			else
			 	Warning "The log file could not be located:\n^$logFile"
			fi
		fi
		[[ -f "$(dirname "$logFile")/script" ]] && rm -f "$(dirname "$logFile")/script"

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
	grepStr="$(getent group leepfrog | grep $userName)"
	if [[ -z $grepStr ]]; then
		echo -e "\nSorry, your userid '$userName' is not in the Unix group: 'leepfrog', please contact the Unix system administrators"
		exit -1
	fi

## Set tmpRoot directory
	tmpRoot=/tmp/$LOGNAME
	[[ ! -d $tmpRoot ]] && mkdir -p $tmpRoot

#echo; echo "HERE 0a HERE 0a HERE"; read
#==================================================================================================
# Parse arguments
#==================================================================================================
## Initial Checks
	[[ -z $TOOLSPATH ]] && echo -e "\n*Error* -- The TOOLSPATH environment value has not been set, cannot continue\n" && exit -3

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
	[[ -z $USEDEV ]] && unset useDev || useDev=$USEDEV
	[[ -z $USELOCAL ]] && unset useLocal || useLocal=$USELOCAL
	[[ -z $VIACRON ]] && unset viaCron || viaCron=$VIACRON

	for token in $loaderArgs; do
		if [[ ${token:0:2} == '--' ]]; then
			[[ ${token,,[a-z]} == '--nolog' ]] && { noLog=true && noLogInDb=true; loaderArgs=${*/$token/}; }
			[[ ${token,,[a-z]} == '--nologindb' ]] && { noLogInDb=true; loaderArgs=${*/$token/}; }
			[[ ${token,,[a-z]} == '--batchmode' ]] && { batchMode=true && myQuiet=true; loaderArgs=${*/$token/}; }
			[[ ${token,,[a-z]} == '--devdb' ]] && { useDevDb=true; loaderArgs=${*/$token/}; }
			[[ ${token,,[a-z]} == '--usedevdb' ]] && { useDevDb=true; loaderArgs=${*/$token/}; }
			[[ ${token,,[a-z]} == '--quiet' ]] && { myQuiet=true; loaderArgs=${*/$token/}; }
			[[ ${token,,[a-z]} == '--reload' ]] && { unset defaultsLoaded; loaderArgs=${*/$token/}; }
		fi
	done
	#fastDump callPgmName noLog noLogInDb batchMode usedevdb myQuiet USELOCAL USEDEV VIACRON PAUSEATEXIT loaderArgs

## Hello
# [[ $batchMode != true && $(hostname) == 'build7.leepfrog.com' ]] && \
# 	echo -e "\tNote: (loader) File system access from the current host has been found to be a bit slow,\n\tPatience you must have, my young padawan..." >&3

## If called as ourselves, then the first token is the script name to call
	if [[ $callPgmName == 'loader.sh' ]]; then
		callPgmName=$(cut -d' ' -f1 <<< $loaderArgs)
		[[ $callPgmName == $loaderArgs ]] && unset loaderArgs || loaderArgs=$(cut -d' ' -f2- <<< $loaderArgs)
	fi
	# fastDump callPgmName loaderArgs

#==================================================================================================
# MAIN
#==================================================================================================
## Add our Java to the front of the user's path
	savePath="$PATH"
	export PATH="$TOOLSPATH/java/bin:$PATH"

## Initialize the runtime environment
	TERM=${TERM:-dumb}
	shopt -s checkwinsize
	set -e  # Turn ON Exit immediately
	#set +e  # Turn OFF Exit immediately

	tabStr='    '
	[[ -z $indentLevel ]] && indentLevel=0 && export indentLevel=$indentLevel
	[[ -z $verboseLevel ]] && verboseLevel=0 && export verboseLevel=$verboseLevel
	epochStime=$(date +%s)

	hostName=$(hostname); hostName=${hostName%%.*}
	osType="$(uname -m)" # x86_64 or i686
	osName='linux'
	[[ ${osType:0:1} = 'x' ]] && osVer=64 || osVer=32

	myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
	[[ $myRhel == 'release' ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

	## set default values for common variables
		if [[ $myName != 'bashShell' ]]; then
			trueVars="verify traceLog trapExceptions logInDb allowAlerts waitOnForkedProcess defaultValueUseNotes"

			falseVars="testMode noEmails noHeaders noCheck noLog verbose quiet warningMsgsIssued errorMsgsIssued noClear"
			falseVars="$falseVars force newsDisplayed noNews informationOnlyMode secondaryMessagesOnly changesMade fork"
			falseVars="$falseVars onlyCimsWithTestFile displayGoodbyeSummaryMessages autoRemote"

			clearVars="helpSet helpNotes warningMsgs errorMsgs summaryMsgs myRealPath myRealName changeLogRecs parsedArgStr"

			for var in $trueVars;  do [[ -z ${!var} ]] && eval "$var=true"; done
			for var in $falseVars; do [[ -z ${!var} ]] && eval "$var=false"; done
			for var in $clearVars; do unset $var; done
		fi

## Import things we need to continue
	source "$TOOLSPATH/lib/Import.sh"
	Import "$loaderIncludes"
	SetFileExpansion

## Load tools defaults value
	[[ ToolsDefaultsLoaded != true ]] && { SetDefaults; }

## Set forking limit
	maxForkedProcesses=$maxForkedProcessesPrime
	[[ -n $scriptData3 && $(IsNumeric $scriptData3) == true ]] && maxForkedProcesses=$scriptData3
	hour=$(date +%H); hour=${hour#0}
	[[ $hour -ge 20 && $maxForkedProcessesAfterHours -gt $maxForkedProcesses ]] && maxForkedProcesses=$maxForkedProcessesAfterHours
	[[ -z $maxForkedProcesses ]] && maxForkedProcesses=3

# If the user has a .tools file then read the values into a hash table
	if [[ -r "$HOME/$userName.cfg" || -r "$HOME/tools.cfg" ]]; then
		[[ -r "$HOME/tools.cfg" ]] && configFile="$HOME/tools.cfg"
		[[ -r "$HOME/$userName.cfg" ]] && configFile="$HOME/$userName.cfg"
		foundToolsSection=false
		ifsSave="$IFS"; IFS=$'\n'; while read -r line; do
			line=$(tr -d '\011\012\015' <<< "$line")
			[[ -z $line || ${line:0:1} == '#' || ${line:0:2} == '//' ]] && continue
			[[ ${line:0:7} == '[tools]' ]] && foundToolsSection=true && continue
			[[ $foundToolsSection != true ]] && continue
			[[ $foundToolsSection == true && ${line:0:1} == '[' ]] && break
			vName="${line%%=*}"; vValue="${line##*=}"
			[[ $(Contains ",${allowedUserVars}," ",${vName},") == false ]] && Error "Variable '$vName' not allowed in tools.cfg file, setting will be ignored" && continue
			vValue=$(cut -d'=' -f2 <<< "$line"); [[ -z $vName ]] && $(cut -d':' -f2 <<< "$line")
			eval $vName=\"$vValue\"
		done < "$configFile"
		IFS="$ifsSave"

		function ColorD { local string="$*"; echo "${colorDefaultVal}${string}${colorDefault}"; }
		function ColorK { local string="$*"; echo "${colorKey}${string}${colorDefault}"; }
		function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
		function ColorN { local string="$*"; echo "${colorNote}${string}${colorDefault}"; }
		function ColorW { local string="$*"; echo "${colorWarn}${string}${colorDefault}"; }
		function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
		function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
		function ColorV { local string="$*"; echo "${colorVerbose}${string}${colorDefault}"; }
		function ColorM { local string="$*"; echo "${colorMenu}${string}${colorDefault}"; }
		export -f ColorD ColorK ColorI ColorN ColorW ColorE ColorT ColorV ColorM
	fi

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
	if [[ -n $checkMsg && $checkMsg != true ]]; then
		if [[ $(Contains ",$administrators," ",$userName,") == true ]]; then
			echo; echo; Warning "$checkMsg"; echo; Alert 2;
		else
			[[ $callPgmName != 'testsh' ]] && { echo; echo; Terminate "$checkMsg"; }
		fi
	fi

## Check Auth
	rc=0
	[[ $callPgmName != "courseleafPatch" ]] && { CallC toolsAuthCheck "$callPgmName"; rc=$?; }
	[[ $rc -ne 0 ]] && exit -1

## Check semaphore
	[[ $(Contains ",$setSemaphoreList," ",$callPgmName," ) == true ]] && semaphoreId=$(CheckSemaphore "$callPgmName" "$waitOn")

## Resolve the executable file"
	[[ -z $executeFile ]] && executeFile=$(FindExecutable "$callPgmName")
	[[ -z $executeFile || ! -r $executeFile ]] && { echo; echo; Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"; }

## Call the script
	## Initialize the log file
		logFile=/dev/null
		if [[ $noLog != true ]]; then
			logFile=$logsRoot$callPgmName/$userName--$backupSuffix.log
			if [[ ! -d $(dirname $logFile) ]]; then
				[[ -f $(dirname $logFile) ]] && rm -f "$(dirname $logFile)"
				mkdir -p "$(dirname $logFile)"
				chown -R "$userName:leepfrog" "$(dirname $logFile)"
				chmod -R 775 "$(dirname $logFile)"
			fi
			touch "$logFile"
			chmod 660 "$logFile"
			chown "$userName:leepfrog" "$logFile"
			Msg "$(PadChar)" > $logFile
			[[ -n $loaderArgs ]] && loaderArgsTxt=" $loaderArgs" || unset loaderArgsTxt
			Msg "$myName:\n^$executeFile\n^$(date)\n^^${callPgmName}${loaderArgsTxt}" >> $logFile
			Msg "$(PadChar)" >> $logFile
			Msg >> $logFile
		fi

	## Call program function
		myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
		myPath="$(dirname $executeFile)"
		declare -A clientData
		## Strip off first token if it is $myName
		[[ $loaderArgs == $myName ]] && unset loaderArgs || loaderArgs="${loaderArgs#$myName }"
		[[ $batchMode != true && $myQuiet != true ]] && echo
		TrapSigs 'off'
		trap "CleanUp" EXIT ## Set trap to return here for cleanup
		[[ $(cut -d' ' -f1 <<< $(wc -l "$executeFile")) -eq 0 ]] && Terminate "Execution file ($executeFile) is empty"
		source $executeFile $loaderArgs 2>&1 | tee -a $logFile; rc=$?
		[[ $logFile != '/dev/null' ]] && touch "$(dirname $logFile)"

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
## 08-07-2017 @ 15.49.31 - ("1.3.36")  - dscudiero - Set the UserAuthGroups global variable
## 08-24-2017 @ 10.06.49 - dscudiero - Add SendEmail to default import list
## 09-28-2017 @ 13.01.36 - ("1.3.57")  - dscudiero - Set globel USELOCAL if script begins with 'test'
## 09-29-2017 @ 13.25.00 - ("1.3.95")  - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.14.55 - ("1.4.-1")  - dscudiero - add debug
## 09-29-2017 @ 15.16.39 - ("1.4.-1")  - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.30.02 - ("1.4.-1")  - dscudiero - Add debug stuff
## 10-02-2017 @ 12.44.30 - ("1.4.-1")  - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.00.33 - ("1.4.-1")  - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.10.08 - ("1.4.-1")  - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.12.23 - ("1.4.0")   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.16.37 - ("1.4.2")   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 14.22.06 - ("1.4.3")   - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.27.27 - ("1.4.4")   - dscudiero - add debug statement
## 10-03-2017 @ 14.36.28 - ("1.4.5")   - dscudiero - Add setting UserAuthGroups
## 10-03-2017 @ 14.39.42 - ("1.4.6")   - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.42.23 - ("1.4.7")   - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.59.39 - ("1.4.10")  - dscudiero - Comment out the UserAuthGroup stuff
## 10-03-2017 @ 15.46.56 - ("1.4.26")  - dscudiero - Uncomment the UserAuthGroups data
## 10-04-2017 @ 12.47.15 - ("1.4.27")  - dscudiero - Comment out the UserAuthGroups stuff
## 10-11-2017 @ 09.44.36 - ("1.4.28")  - dscudiero - Add Debug statements
## 10-11-2017 @ 09.45.43 - ("1.4.28")  - dscudiero - Remove debug statements
## 10-11-2017 @ 09.55.24 - ("1.4.30")  - dscudiero - Remove debug
## 10-11-2017 @ 10.52.27 - ("1.4.32")  - dscudiero - change how log file is created
## 10-11-2017 @ 10.58.36 - ("1.4.33")  - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 11.26.38 - ("1.4.35")  - dscudiero - Send the startup message to the logFile only
## 10-11-2017 @ 11.50.27 - ("1.4.40")  - dscudiero - Cleanup logfile initialization
## 10-11-2017 @ 12.51.16 - ("1.4.41")  - dscudiero - If calling scripts or reports then do not build a log file
## 10-12-2017 @ 14.51.44 - ("1.4.43")  - dscudiero - Pull the users auth groups and put in a variable
## 10-19-2017 @ 12.19.26 - ("1.4.44")  - dscudiero - touch the logFile upon return to set time date stamp
## 10-20-2017 @ 16.55.59 - ("1.4.45")  - dscudiero - Add loading of the argDefs array
## 10-20-2017 @ 16.56.45 - ("1.4.46")  - dscudiero - remove debug line
## 10-23-2017 @ 11.03.47 - ("1.4.47")  - dscudiero - Make sure the permissions of the log files is 644
## 10-23-2017 @ 16.21.45 - ("1.4.48")  - dscudiero - Make sure we can list the log directories
## 10-23-2017 @ 16.28.49 - ("1.4.49")  - dscudiero - Cosmetic/minor change
## 10-24-2017 @ 07.57.46 - ("1.4.50")  - dscudiero - Cosmetic/minor change
## 10-26-2017 @ 08.07.31 - ("1.4.52")  - dscudiero - Cosmetic/minor change
## 10-31-2017 @ 10.41.31 - ("1.4.54")  - dscudiero - Cosmetic/minor change
## 10-31-2017 @ 15.30.53 - ("1.4.55")  - dscudiero - Use | as seperator in argDefs
## 10-31-2017 @ 15.32.39 - ("1.4.56")  - dscudiero - Cosmetic/minor change
## 11-03-2017 @ 13.55.07 - ("1.4.57")  - dscudiero - Un comment setting of UserAuthGroups
## 11-06-2017 @ 07.22.48 - ("1.4.60")  - dscudiero - Switch to using the auth files
## 11-06-2017 @ 10.03.24 - ("1.4.29")  - dscudiero - Use the auth files
## 11-06-2017 @ 13.59.46 - ("1.4.30")  - dscudiero - Remove build7 is slow message
## 11-14-2017 @ 11.51.02 - ("1.4.31")  - dscudiero - Do not touch the log file if it is /dev/null
## 11-14-2017 @ 11.52.21 - ("1.4.32")  - dscudiero - Cosmetic/minor change
## 11-14-2017 @ 11.58.15 - ("1.4.39")  - dscudiero - Do not touch the log directory if the logFile is /dev/null
## 12-01-2017 @ 09.09.59 - ("1.4.42")  - dscudiero - Remove autoRemote from the trueVars set
## 12-04-2017 @ 11.18.15 - ("1.4.51")  - dscudiero - Added loading of user tools.cfg file
## 03-20-2018 @ 17:36:55 - 1.4.135 - dscudiero - Comment out debug statements
## 03-21-2018 @ 11:31:50 - 1.4.136 - dscudiero - Add our own java to the path
## 03-21-2018 @ 11:38:57 - 1.4.138 - dscudiero - Cosmetic/minor change/Sync
## 03-21-2018 @ 11:41:04 - 1.4.139 - dscudiero - Turn on loading messages
## 03-23-2018 @ 16:43:24 - 1.4.140 - dscudiero - Updates Msg3/Msg
## 04-18-2018 @ 09:34:25 - 1.5.1 - dscudiero - Re factored to use useDev
## 04-18-2018 @ 13:41:36 - 1.5.2 - dscudiero - D
## 04-19-2018 @ 07:13:18 - 1.5.3 - dscudiero - Re-factor how we detect viaCron
## 04-19-2018 @ 08:11:10 - 1.5.4 - dscudiero - Add debug statements
## 04-19-2018 @ 12:06:48 - 1.5.5 - dscudiero - Display checkRun messages if admins
## 04-19-2018 @ 12:22:09 - 1.5.11 - dscudiero - Fix problem continuing for admins if script is off-line
## 04-19-2018 @ 16:52:01 - 1.5.15 - dscudiero - Fixed problem passing -- arguments on to the called script
## 04-20-2018 @ 07:21:09 - 1.5.16 - dscudiero - Remove debug
## 04-20-2018 @ 11:17:53 - 1.5.17 - dscudiero - Remove debug statements
## 04-25-2018 @ 11:52:08 - 1.5.18 - dscudiero - Add --reload option
## 05-24-2018 @ 08:51:03 - 1.5.19 - dscudiero - Comment out code that edited out the callPgmName ~ 136
## 05-24-2018 @ 09:23:34 - 1.5.22 - dscudiero - Tweak code that removes the loadPgmName
## 05-25-2018 @ 11:40:57 - 1.5.31 - dscudiero - Add code to cache the script authorization data
## 05-25-2018 @ 15:08:06 - 1.5.32 - dscudiero - Pause if there is an authorization error and the user is an administrator
## 05-29-2018 @ 13:17:35 - 1.5.34 - dscudiero - Add declaration or the clientData hash table
## 05-29-2018 @ 16:43:55 - 1.5.36 - dscudiero - Comment out debug stuff
## 06-05-2018 @ 13:59:24 - 1.5.36 - dscudiero - Add debug
## 06-05-2018 @ 14:09:01 - 1.5.36 - dscudiero - Add a pause statement if admin and checkRun failed
## 06-05-2018 @ 15:23:33 - 1.5.36 - dscudiero - Cosmetic/minor change/Sync
## 06-05-2018 @ 16:56:54 - 1.5.36 - dscudiero - Cosmetic/minor change/Sync
## 06-12-2018 @ 08:18:06 - 1.5.47 - dscudiero - Fix bug / optimize parameter parsing
## 06-14-2018 @ 15:19:51 - 1.5.47 - dscudiero - Treat // as a comment line in the config file
## 06-18-2018 @ 08:12:39 - 1.5.58 - dscudiero - Refactor authorization checks
## 06-18-2018 @ 10:11:44 - 1.5.58 - dscudiero - Do not check auth if script being loaded is 'scripts'
## 06-27-2018 @ 14:08:15 - 1.5.58 - dscudiero - Do not check auth if script name is testsh
## 07-12-2018 @ 12:47:36 - 1.5.59 - dscudiero - Update the script auth checking to allow for '|' delimited script names in UserScriptsStr
## 07-12-2018 @ 13:01:13 - 1.5.59 - dscudiero - Update auth check to allow for '|' prefixed script names in the UserScriptsStr
## 07-16-2018 @ 11:28:49 - 1.5.60 - dscudiero - Strip off the type prefix strings on UsersAuthGroups and UsersScriptsStr
## 07-16-2018 @ 12:36:47 - 1.5.60 - dscudiero - Strip off the type prefix strings on UsersAuthGroups and UsersScriptsStr
## 08-27-2018 @ 07:48:14 - 1.5.61 - dscudiero - Put in a check to make sure the user is in the leepfrog group
## 08-27-2018 @ 07:50:42 - 1.5.62 - dscudiero - Cosmetic/minor change/Sync
## 10-15-2018 @ 11:09:31 - 1.5.63 - dscudiero - Make sure that there is not a script file in the Logs directory on exit
## 11-05-2018 @ 10:14:25 - 1.5.83 - dscudiero - Switch to use CheckAuth module
## 11-07-2018 @ 14:33:47 - 1.5.84 - dscudiero - Remove -fromFiles from GetDefaultsData call
## 11-16-2018 @ 09:52:04 - 1.6.3 - dscudiero - Add breadcrumbs
## 11-16-2018 @ 09:54:43 - 1.6.4 - dscudiero - Cosmetic/minor change/Sync
## 12-03-2018 @ 07:41:11 - 1.6.14 - dscudiero - Fix call to toolsAuthCheck to be rhel specific
## 12-03-2018 @ 08:39:55 - 1.6.15 - dscudiero - Comment out the calls to prtStatus
## 12-03-2018 @ 09:41:02 - 1.6.16 - dscudiero - Put in a fixx for the script is a file in the logs directory problem
## 12-06-2018 @ 14:30:02 - 1.6.18 - dscudiero - Updated to use toolsSetDefaults
## 12-18-2018 @ 08:37:35 - 1.6.27 - dscudiero - Switch to use SetDefaults function
## 04-30-2019 @ 12:07:52 - 1.6.29 - dscudiero -  Do not do auth check for courseleafPatch
## 04-30-2019 @ 12:33:58 - 1.6.30 - dscudiero - 
## 05-24-2019 @ 14:00:04 - 1.6.30 - dscudiero - 
## 06-07-2019 @ 09:06:27 - 1.6.30 - dscudiero - 
## 06-07-2019 @ 09:32:02 - 1.6.30 - dscudiero - 
## 06-07-2019 @ 09:46:21 - 1.6.30 - dscudiero - 
## Fri Jun  7 10:39:08 CDT 2019 - dscudiero - Sync
## 06-07-2019 @ 14:25:40 - 1.6.31 - dscudiero - Cosmetic / Miscellaneous cleanup / Sync
