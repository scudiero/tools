#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.24 # -- dscudiero -- Tue 10/31/2017 @  8:30:55.33
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
	if [[ ! -d "$TOOLSPATH/Logs/cronJobs"  ]]; then 
		mkdir -p "$TOOLSPATH/Logs/cronJobs"
		chown -R "$userName:leepfrog" "$TOOLSPATH/Logs/cronJobs"
		chmod 770 "$TOOLSPATH/Logs/cronJobs"
	fi
	echo "$hostName - $(date +'%m-%d-%Y @ %H.%M.%S') -- Starting $callScriptName" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log

Here 0A; dump verboseLevel
#=======================================================================================================================
## Initialize the runtime env
	##echo -e "\t-- $hostName - sourcing '$dispatcher'" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
	source "$dispatcher" --viaCron ## Setup the environment
	#3echo -e "\t\t-- $hostName - back from dispatcher" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
Here 0B; dump verboseLevel

#=======================================================================================================================
## Set the jobs the log file
	#if [[ $callScriptName != 'hourly' ]]; then
		[[ ! -d $TOOLSPATH/Logs/cronJobs/$callScriptName ]] && mkdir -p $TOOLSPATH/Logs/cronJobs/$callScriptName
		logFile="$TOOLSPATH/Logs/cronJobs/$callScriptName/$hostName-$(date +'%m-%d-%Y_%H.%M.%S').log"
	#else
	#	logFile="/dev/null"
	#fi

#=======================================================================================================================
## Run the executable(s)
	export USELOCAL=true
	executeFile=$(FindExecutable "$callScriptName" '-cron')
Here 0C; dump verboseLevel
	echo -e "\t-- $hostName - Starting $callScriptName from '$executeFile', Args: $scriptArgs $callScriptArgs" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
	echo -e "\n$(date) -- Calling script '$callScriptName':\n\t$executeFile $callScriptArgs\n" > "$logFile"

	myNameSave="$myName"; myPathSave="$myPath"
	myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
	myPath="$(dirname $executeFile)"
	source $executeFile $scriptArgs $callScriptArgs >> "$logFile"  2>&1
	echo -e "\t-- $hostName - $callScriptName done" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
	mv $logFile $logFile.bak
 	cat $logFile.bak | sed "s/\x1B\[[0-9;]*[a-zA-Z]//g" | tr -d '\007' > $logFile
	chmod 660 "$logFile"
 	rm $logFile.bak
	[[ ! -d $(dirname $logFile) ]] && { touch "$(dirname $logFile)"; chmod 770 "$(dirname $logFile)"; }
	myName="$myNameSave"; myPath="$myPathSave"

#=======================================================================================================================
## Scan the logFile looking for errors
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

	## Trim the cronJob log file
	if [[ $(date "+%H") == 22 ]]; then 
		tail -n 25 "$TOOLSPATH/Logs/cronJobs/cronJobs.log" > "/tmp/cronJobs.log"
		cp -f "/tmp/cronJobs.log" "$TOOLSPATH/Logs/cronJobs/cronJobs.log"
		rm -f "/tmp/cronJobs.log"
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
## 10-10-2017 @ 14.09.18 - (2.0.109)   - dscudiero - add --cron flag on findExcutable call
## 10-10-2017 @ 15.52.43 - (2.0.110)   - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 07.31.15 - (2.0.111)   - dscudiero - Cosmetic/minor change
## 10-12-2017 @ 14.44.23 - (2.1.0)     - dscudiero - Cosmetic/minor change
## 10-13-2017 @ 14.37.01 - (2.1.1)     - dscudiero - Add debug stuff
## 10-16-2017 @ 12.38.52 - (2.1.5)     - dscudiero - Tweak how we call the script
## 10-16-2017 @ 12.56.41 - (2.1.6)     - dscudiero - Cosmetic/minor change
## 10-16-2017 @ 13.06.35 - (2.1.7)     - dscudiero - Fix call to FindExecutable
## 10-16-2017 @ 15.06.11 - (2.1.9)     - dscudiero - Remove the subshell parens arround the script source stmt
## 10-17-2017 @ 14.07.48 - (2.1.10)    - dscudiero - Make sure myName is set correctly
## 10-19-2017 @ 12.19.35 - (2.1.11)    - dscudiero - touch the logFile upon return to set time date stamp
## 10-19-2017 @ 15.12.53 - (2.1.12)    - dscudiero - Cleanup the logFile from called task
## 10-23-2017 @ 11.03.55 - (2.1.13)    - dscudiero - Make sure the permissions of the log files is 644
## 10-23-2017 @ 16.21.52 - (2.1.14)    - dscudiero - Make sure we can list the log directories
## 10-24-2017 @ 07.10.35 - (2.1.15)    - dscudiero - Cosmetic/minor change
## 10-24-2017 @ 08.02.04 - (2.1.16)    - dscudiero - Cosmetic/minor change
## 10-24-2017 @ 09.15.44 - (2.1.17)    - dscudiero - Cosmetic/minor change
## 10-24-2017 @ 13.52.52 - (2.1.18)    - dscudiero - Fix log directory creation
## 10-26-2017 @ 07.59.35 - (2.1.19)    - dscudiero - tweak log file redirects
## 10-27-2017 @ 08.18.56 - (2.1.20)    - dscudiero - Add cleanup code to keep the cronjob.log a reasonable size
## 10-27-2017 @ 09.36.59 - (2.1.22)    - dscudiero - Set USELOCAL before resolving sript file
## 10-27-2017 @ 09.41.18 - (2.1.23)    - dscudiero - Remove debug stuff
