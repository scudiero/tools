#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.59" # -- dscudiero -- 12/28/2016 @ 16:04:13.34
#===================================================================================================
# Initialize the tools runtime environment
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
# commonIncludes='Colors Msg2 Dump Here Quit Contains Lower Upper TitleCase Trim IsNumeric PushSettings PopSettings'
# commonIncludes="$commonIncludes MkTmpFile Pause ProtectedCall SetFileExpansion PadChar PrintBanner Alert"
# commonIncludes="$commonIncludes TrapSigs SignalHandeler RunSql DbLog GetCallStack DisplayNews"
# commonIncludes="$commonIncludes GetDefaultsData Call StartRemoteSession"
# Import "$commonIncludes"
TrapSigs 'on'

GD echo -e "\n=== Starting InitializeRuntime ========================================================================"

unset helpSet helpNotes warningMsgs errorMsgs summaryMsgs myRealPath myRealName changeLogRecs parsedArgStr

## Make sure we have avalue for TERM
[[ $TERM == '' ]] && export TERM=xterm
shopt -s checkwinsize
set +e  # Turn OFF Exit immediately

#echo "In framework. indentLevel = >$indentLevel<"
[[ $indentLevel == '' ]] && indentLevel=0 && export indentLevel=$indentLevel
[[ $verboseLevel == '' ]] && verboseLevel=0 && export verboseLevel=$verboseLevel
epochStime=$(date +%s)
hostName=$(hostname)
hostName="$(echo $hostName | cut -d"." -f1)"
osType="$(echo `uname -m`)" # x86_64 or i686
osName='linux'
osVer=$(uname -m)
if [[ ${osVer:0:1} = 'x' ]]; then osVer=64; else osVer=32; fi
myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
[[ $(IsNumeric ${myRhel:0:1}) != true ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

[[ $_ != $0 ]] && sourcePath=$(dirname ${BASH_SOURCE[0]}) || unset sourcePath

tabStr="$(PadChar ' ' 5)"

## set default values
	if [[ $myName != 'bashShell' ]]; then
		trueVars="verify traceLog trapExceptions logInDb allowAlerts waitOnForkedProcess defaultValueUseNotes"
		for var in $trueVars; do [[ $(eval echo \$$var) == '' ]] && eval "$var=true"; done

		falseVars="testMode noEmails noHeaders noCheck noLog verbose quiet warningMsgsIssued errorMsgsIssued noClear"
		falseVars="$falseVars force newsDisplayed noNews informationOnlyMode secondaryMessagesOnly changesMade fork"
		falseVars="$falseVars onlyCimsWithTestFile displayGoodbyeSummaryMessages autoRemote"
		for var in $falseVars; do [[ $(eval echo \$$var) == '' ]] && eval "$var=false"; done
	fi
	localVarList="$trueVars $falseVars"

## Trap interrupts
	TrapSigs 'on'

## Load defaults value
	GetDefaultsData
	SetFileExpansion
## If the user has a .tools file then read the values into a hash table
	#echo "allowedUserVars = >$allowedUserVars<"
	if [[ -r "$HOME/tools.cfg" && ${myRhel:0:1} -gt 5 ]]; then
		ifs="$IFS"; IFS=$'\n'; while read -r line; do
			line=$(tr -d '\011\012\015' <<< "$line")
			[[ $line == '' || ${line:0:1} == '#' ]] && continue
			vName=$(cut -d'=' -f1 <<< "$line"); [[ $vName == '' ]] && $(cut -d':' -f1 <<< "$line")
			[[ $(Contains ",${allowedUserVars}," ",${vName},") == false ]] && Msg2 $E "Variable '$vName' not allowed in tools.cfg file, setting will be ignored" && continue
			vValue=$(cut -d'=' -f2 <<< "$line"); [[ $vName == '' ]] && $(cut -d':' -f2 <<< "$line")
			eval $vName=\"$vValue\"
		done < "$HOME/tools.cfg"
		IFS="$ifs"
		# Redefine Color functions (set after we have read user config file)
		function ColorD { local string="$*"; echo "${colorDefaultVal}${string}${colorDefault}"; }
		function ColorK { local string="$*"; echo "${colorKey}${string}${colorDefault}"; }
		function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
		function ColorN { local string="$*"; echo "${colorNote}${string}${colorDefault}"; }
		function ColorW { local string="$*"; echo "${colorWarn}${string}${colorDefault}"; }
		function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
		function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
		function ColorV { local string="$*"; echo "${colorVerbose}${string}${colorDefault}"; }
		function ColorM { local string="$*"; echo "${colorMenu}${string}${colorDefault}"; }
	fi

	# Msg " Default Color $(ColorK "This is ColorK") Default Color"
	# Msg " Default Color $(ColorI "This is ColorI") Default Color"
	# Msg " Default Color $(ColorN "This is ColorN") Default Color"
	# Msg " Default Color $(ColorW "This is ColorW") Default Color"
	# Msg " Default Color $(ColorE "This is ColorE") Default Color"
	# Msg " Default Color $(ColorT "This is ColorT") Default Color"
	# Msg " Default Color $(ColorV "This is ColorV") Default Color"

## Set forking limit
	maxForkedProcesses=$maxForkedProcessesPrime
	[[ $scriptData3 != '' && $(IsNumeric $scriptData3) == true ]] && maxForkedProcesses=$scriptData3
	hour=$(date +%H)
	hour=${hour#0}
	[[ $hour -ge 20 && $maxForkedProcessesAfterHours -gt $maxForkedProcesses ]] && maxForkedProcesses=$maxForkedProcessesAfterHours
	[[ $maxForkedProcesses == '' ]] && maxForkedProcesses=3

## Set the CLASSPATH
	sTime=$(date "+%s")
	saveClasspath="$CLASSPATH"
	searchDirs="$TOOLSPATH/src"
	[[ $TOOLSSRCPATH != '' ]] && searchDirs="$( tr ':' ' ' <<< $TOOLSSRCPATH)"
	unset CLASSPATH
	for searchDir in $searchDirs; do
		for jar in $(find $searchDir/java -mindepth 1 -maxdepth 1 -type f -name \*.jar); do
			[[ $CLASSPATH == '' ]] && CLASSPATH="$jar" || CLASSPATH="$CLASSPATH:$jar"
		done
	done
	export CLASSPATH="$CLASSPATH"

export FRAMEWORKLOADED=true
GD echo -e "\n=== Stopping InitializeRuntime ========================================================================"

#===================================================================================================
## Check-in log
#===================================================================================================
## Thu Dec 29 07:04:46 CST 2016 - dscudiero - Removed the CLASSPATH setting code
