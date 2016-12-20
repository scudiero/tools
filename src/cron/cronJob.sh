#!/bin/bash
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.0.72 # -- dscudiero -- 12/20/2016 @ 14:45:46.12
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

	export TOOLSPATH=/steamboat/leepfrog/docs/toolsNew
	dispatcher="$TOOLSPATH/src/dispatcher.sh"

	if [[ -x $HOME/$toolsRepo/dispatcher.sh ]]; then
		localmd5=$(md5sum "$HOME/$toolsRepo/src/dispatcher.sh" | cut -f1 -d" "))
		prodmd5=$(md5sum "$TOOLSPATH/src/dispatcher.sh" | cut -f1 -d" "))
		[[ $localmd5 != $prodmd5 ]] && dispatcher="$HOME/$toolsRepo/src/dispatcher.sh"
	fi
	export TOOLSLIBPATH="$TOOLSPATH/lib"
	[[ -d $HOME/$toolsRepo/lib ]] && export TOOLSLIBPATH="$HOME/$toolsRepo/lib:$TOOLSLIBPATH"
	export TOOLSSRCPATH="$TOOLSPATH/src"
	[[ -d $HOME/$toolsRepo/src ]] && export TOOLSSRCPATH="$HOME/$toolsRepo/src:$TOOLSSRCPATH"

#=======================================================================================================================
## Initialize the runtime env
	source $dispatcher  --batchMode ## Setup the environment

#=======================================================================================================================
## Log the cronJob
	[[ ! -d $TOOLSPATH/Logs/cronJobs ]] && mkdir -p $TOOLSPATH/Logs/cronJobs
	echo "$(date +%m-%d-%Y@%H.%M.%S) - $hostName - Starting $callScriptName" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
## Set the jobs the log file
	[[ ! -d $TOOLSPATH/Logs/cronJobs/$callScriptName ]] && mkdir -p $TOOLSPATH/Logs/cronJobs/$callScriptName
	logFile=$TOOLSPATH/Logs/cronJobs/$callScriptName/$hostName-$(date +%m-%d-%Y@%H.%M.%S).log

#=======================================================================================================================
## Run the executable
	useLocal=true
	Call "$callScriptName" 'std' 'cron:sh' "$callScriptArgs" > $logFile 2>&1

#=======================================================================================================================
## Post process the logFile
	## Turn off error traps
	set +eE ; trap - ERR
	## If logFile is empty then just remove it, otherwise scan for errors
	if [[ -f $logFile ]]; then
		if [[ $(cut -d' ' -f1 <<< $(wc -l $logFile)) -eq 0 ]]; then
			rm -f $logFile
		else
			tmpFile1="/tmp/$callScriptName.$$.dat"
			tmpFile2="$tmpFile1.msg"
			for token in error invalid warning; do
				\grep -i "$token" $logFile > $tmpFile1; rc=$?
				if [[ $rc -eq 0 ]]; then
					echo -e "\nFound error token '$token' in the logfile \n\t$logFile\nfor $callScriptName\n" > $tmpFile2
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