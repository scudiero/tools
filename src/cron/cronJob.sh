#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.0.90 # -- dscudiero -- 01/05/2017 @ 12:22:24.46
#=======================================================================================================================
# Cron task initiator
#=======================================================================================================================
originalArgStr="$*"

#=======================================================================================================================
# Parse Args
	callScriptName=$1; shift
	callScriptArgs="$* -noPrompt -noLogInDb -batchMode -fork"

#=======================================================================================================================
# Set defaults
	toolsRepo='tools'
	UsePythonVer='3'
	notifyAddrs='dscudiero@leepfrog.com'
	hostName=$(cut -d'.' -f1 <<< $(hostname))

	[[ $HOME/bin ]] && export PATH="$HOME/bin:$PATH"

	export TOOLSPATH='/steamboat/leepfrog/docs/tools'
	[[ -d '/steamboat/leepfrog/docs/toolsNew' ]] && export TOOLSPATH='/steamboat/leepfrog/docs/toolsNew'

	dispatcher="$TOOLSPATH/dispatcher.sh"
	if [[ -x $HOME/$toolsRepo/dispatcher.sh ]]; then
		localmd5=$(md5sum "$HOME/$toolsRepo/dispatcher.sh" | cut -f1 -d" ")
		prodmd5=$(md5sum "$TOOLSPATH/dispatcher.sh" | cut -f1 -d" ")
		[[ $localmd5 != $prodmd5 ]] && dispatcher="$HOME/$toolsRepo/dispatcher.sh"
	fi
	export DISPATCHER="$dispatcher"
	export TOOLSLIBPATH="$TOOLSPATH/lib"
	[[ -d $HOME/$toolsRepo/lib ]] && export TOOLSLIBPATH="$HOME/$toolsRepo/lib:$TOOLSLIBPATH"
	export TOOLSSRCPATH="$TOOLSPATH/src"
	[[ -d $HOME/$toolsRepo/src ]] && export TOOLSSRCPATH="$HOME/$toolsRepo/src:$TOOLSSRCPATH"
	# echo
	# echo "PATH= '$PATH'"; echo
	# echo "TOOLSPATH= '$TOOLSPATH'"; echo
	# echo "TOOLSLIBPATH= '$TOOLSLIBPATH'"; echo
	# echo "TOOLSSRCPATH= '$TOOLSSRCPATH'"; echo
	# echo

#=======================================================================================================================
## Initialize the runtime env
	source $dispatcher  --batchMode ## Setup the environment

#=======================================================================================================================
## Log the cronJob
	[[ ! -d $TOOLSPATH/Logs/cronJobs ]] && mkdir -p $TOOLSPATH/Logs/cronJobs
	echo "$hostName - $(date +'%m-%d-%Y @ %H.%M.%S') -- Starting $callScriptName" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
## Set the jobs the log file
	if [[ $callScriptName != 'hourly' ]]; then
		[[ ! -d $TOOLSPATH/Logs/cronJobs/$callScriptName ]] && mkdir -p $TOOLSPATH/Logs/cronJobs/$callScriptName
		logFile="$TOOLSPATH/Logs/cronJobs/$callScriptName/$hostName-$(date +'%m-%d-%Y_%H.%M.%S').log"
	else
		logFile="/dev/null"
	fi

#=======================================================================================================================
## Run the executable
	useLocal=true
	Call "$callScriptName" 'std' 'cron:sh' "$callScriptArgs" > "$logFile" 2>&1

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
					mutt -s "($hostName) $callScriptName - Errors running script" -- $notifyAddrs < $tmpFile2;
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
## Thu Jan  5 12:23:39 CST 2017 - dscudiero - set DISPATCHER
