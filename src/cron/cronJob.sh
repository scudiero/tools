#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.0.107 # -- dscudiero -- Tue 10/10/2017 @ 13:27:33.58
#=======================================================================================================================
# Cron task initiator
#=======================================================================================================================
originalArgStr="$*"

#=======================================================================================================================
# Set defaults
	notifyAddrs='dscudiero@leepfrog.com'
	hostName=$(cut -d'.' -f1 <<< $(hostname))
	[[ $HOME/bin ]] && export PATH="$HOME/bin:$PATH"
	export TOOLSPATH='/steamboat/leepfrog/docs/tools'
	[[ -d '/steamboat/leepfrog/docs/toolsNew' ]] && export TOOLSPATH='/steamboat/leepfrog/docs/toolsNew'
	dispatcher="$TOOLSPATH/dispatcher.sh"

#=======================================================================================================================
# Parse Args
	callScriptName=$1; shift
	callScriptArgs="$* -noPrompt -noLogInDb -batchMode -fork"

#=======================================================================================================================
## Log the cronJob
	[[ ! -d $TOOLSPATH/Logs/cronJobs ]] && mkdir -p $TOOLSPATH/Logs/cronJobs
	echo "$hostName - $(date +'%m-%d-%Y @ %H.%M.%S') -- Starting $callScriptName" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log

#=======================================================================================================================
## Initialize the runtime env
	echo -e "\t-- $hostName - sourcing '$dispatcher'" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
	source "$dispatcher" --viaCron ## Setup the environment
	echo -e "\t\t-- $hostName - back from dispatcher" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log

	executeFile=$(FindExecutable "$callScriptName")
	[[ -z $executeFile || ! -r $executeFile ]] && { echo; echo; Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"; }

#=======================================================================================================================
## Log the cronJob
	echo -e "\t-- $hostName - Starting $callScriptName" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log

## Set the jobs the log file
	#if [[ $callScriptName != 'hourly' ]]; then
		[[ ! -d $TOOLSPATH/Logs/cronJobs/$callScriptName ]] && mkdir -p $TOOLSPATH/Logs/cronJobs/$callScriptName
		logFile="$TOOLSPATH/Logs/cronJobs/$callScriptName/$hostName-$(date +'%m-%d-%Y_%H.%M.%S').log"
	#else
	#	logFile="/dev/null"
	#fi

#=======================================================================================================================
## Run the executable(s)
	useLocal=true
	echo -e "\n$(date) -- Calling script/n" > "$logFile" 2>&1
	source $executeFile $scriptArgs "$callScriptArgs" >> "$logFile" 2>&1
	echo -e "\t-- $hostName - $callScriptName done" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log

#=======================================================================================================================
## Post process the logFile
	## Turn off error traps
	set +eE ; trap - ERR
	## If logFile is empty then just remove it, otherwise scan for errors
	if [[ -f "$logFile" ]]; then
		if [[ $(cut -d' ' -f1 <<< $(wc -l "$logFile")) -eq 0 ]]; then
			rm -f "$logFile"
		else
			tmpFile1="/tmp/$callScriptName.$$.dat"
			tmpFile2="$tmpFile1.msg"
			for token in error invalid warning; do
				\grep -i "$token" "$logFile" > $tmpFile1; rc=$?
				if [[ $rc -eq 0 ]]; then
					echo -e "\nFound error token '$token' in the logfile \n\t"$logFile"\nfor $callScriptName\n" > $tmpFile2
					while read -r line; do
						[[ ${line:0:1} == '*' ]] && echo >> $tmpFile2
						echo -e "\t$line" >> $tmpFile2 ;
					done < $tmpFile1;
					mutt -s "($hostName) $callScriptName - Errors running script" -a "$logFile" -- $notifyAddrs < $tmpFile2;
					break
				fi
			done
			[[ -f $tmpFile1 ]] && rm -f $tmpFile1
			[[ -f $tmpFile2 ]] && rm -f $tmpFile2
		fi
	fi

#=======================================================================================================================
exit 0
#=======================================================================================================================
# Check-in Log
#=======================================================================================================================
## Thu Dec 29 08:18:05 CST 2016 - dscudiero - General syncing of dev to prod
## Thu Dec 29 09:02:34 CST 2016 - dscudiero - Fix problem where the inserted checkin comment was appended to the end of the exit line
## Thu Jan  5 12:23:39 CST 2017 - dscudiero - set loader
## Wed Jan 18 10:03:13 CST 2017 - dscudiero - Added execution of local script if found in logged in users bin directory
## Wed Jan 18 10:50:09 CST 2017 - dscudiero - Add call to local script if found
## Tue Jan 24 16:53:09 CST 2017 - dscudiero - activate log files for hourly
## 06-08-2017 @ 08.50.15 - (2.0.95)    - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 09.18.23 - (2.0.96)    - dscudiero - Add debug statements
## 06-08-2017 @ 10.03.57 - (2.0.97)    - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 10.47.07 - (2.0.98)    - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 10.48.33 - (2.0.99)    - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 11.39.20 - (2.0.100)   - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 12.21.30 - (2.0.101)   - dscudiero - add debug
## 06-08-2017 @ 14.13.19 - (2.0.104)   - dscudiero - General syncing of dev to prod
## 07-31-2017 @ 07.24.49 - (2.0.105)   - dscudiero - Add the name of the cron job called to the log
## 09-08-2017 @ 08.11.18 - (2.0.106)   - dscudiero - Import the Call function before use
## 10-10-2017 @ 13.28.06 - (2.0.107)   - dscudiero - Switch from Call to FindExecutableFile
