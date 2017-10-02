## XO NOT AUTOVERSION
#===================================================================================================
# version="2.1.0" # -- dscudiero -- Mon 10/02/2017 @ 13:06:55.98
#===================================================================================================
# Initialize the tools runtime environment
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
myIncludes="TrapSigs Msg3 GetDefaultsData SetFileExpansion StringFunctions"
Import "$myIncludes"

TrapSigs 'on'
## Make sure we have avalue for TERM
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

[[ $_ != $0 ]] && sourcePath=$(dirname ${BASH_SOURCE[0]}) || unset sourcePath

## set default values
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

## Load defaults value
	defaultsLoaded=false
	GetDefaultsData "$myName" -fromFiles
	SetFileExpansion

	[[ $userName == 'dscudiero' ]] && autoRemote=true

## If the user has a .tools file then read the values into a hash table
	# if [[ -r "$HOME/tools.cfg" ]]; then
	# 	ifs="$IFS"; IFS=$'\n'; while read -r line; do
	# 		line=$(tr -d '\011\012\015' <<< "$line")
	# 		[[ -z $line || ${line:0:1} == '#' ]] && continue
	# 		vName=$(cut -d'=' -f1 <<< "$line"); [[ -z $vName ]] && $(cut -d':' -f1 <<< "$line")
	# 		[[ $(Contains ",${allowedUserVars}," ",${vName},") == false ]] && Error "Variable '$vName' not allowed in tools.cfg file, setting will be ignored" && continue
	# 		vValue=$(cut -d'=' -f2 <<< "$line"); [[ -z $vName ]] && $(cut -d':' -f2 <<< "$line")
	# 		eval $vName=\"$vValue\"
	# 	done < "$HOME/tools.cfg"
	# fi

	# function ColorD { local string="$*"; echo "${colorDefaultVal}${string}${colorDefault}"; }
	# function ColorK { local string="$*"; echo "${colorKey}${string}${colorDefault}"; }
	# function ColorI { local string="$*"; echo "${colorInfo}${string}${colorDefault}"; }
	# function ColorN { local string="$*"; echo "${colorNote}${string}${colorDefault}"; }
	# function ColorW { local string="$*"; echo "${colorWarn}${string}${colorDefault}"; }
	# function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }
	# function ColorT { local string="$*"; echo "${colorTerminate}${string}${colorDefault}"; }
	# function ColorV { local string="$*"; echo "${colorVerbose}${string}${colorDefault}"; }
	# function ColorM { local string="$*"; echo "${colorMenu}${string}${colorDefault}"; }
	# export -f ColorD ColorK ColorI ColorN ColorW ColorE ColorT ColorV ColorM

## Set forking limit
	maxForkedProcesses=$maxForkedProcessesPrime
	[[ -n $scriptData3 && $(IsNumeric $scriptData3) == true ]] && maxForkedProcesses=$scriptData3
	hour=$(date +%H)
	hour=${hour#0}
	[[ $hour -ge 20 && $maxForkedProcessesAfterHours -gt $maxForkedProcesses ]] && maxForkedProcesses=$maxForkedProcessesAfterHours
	[[ -z $maxForkedProcesses ]] && maxForkedProcesses=3

export FRAMEWORKLOADED=true

#===================================================================================================
## Check-in log
#===================================================================================================
## Thu Dec 29 07:04:46 CST 2016 - dscudiero - Removed the CLASSPATH setting code
## Wed Jan  4 13:53:49 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan  4 15:29:42 CST 2017 - dscudiero - Turn on error exit by default
## Thu Jan 12 16:02:43 CST 2017 - dscudiero - Add debug messaging for dscudiero
## Fri Jan 13 07:21:22 CST 2017 - dscudiero - Bring colors processing into this module
## Fri Jan 13 07:22:16 CST 2017 - dscudiero - fix bug
## Fri Jan 13 08:28:37 CST 2017 - dscudiero - misc cleanup
## Fri Jan 13 09:23:21 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan 13 15:11:07 CST 2017 - dscudiero - syc
## Fri Jan 13 15:25:47 CST 2017 - dscudiero - Remove setting classpath
## Fri Jan 13 15:33:26 CST 2017 - dscudiero - remove debug code
## Tue Jan 17 08:55:29 CST 2017 - dscudiero - Move color definitions before getDefaultsData
## 05-05-2017 @ 13.21.21 - ("2.0.77")  - dscudiero - Remove GD code
## 05-10-2017 @ 09.42.22 - ("2.0.79")  - dscudiero - Move TrapSigs to dispatcher
## 05-31-2017 @ 07.26.21 - ("2.0.81")  - dscudiero - Make sure TERM has a value , if not set then set to dumb
## 08-03-2017 @ 07.13.29 - ("2.0.82")  - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.07.57 - ("2.1.0")   - dscudiero - General syncing of dev to prod
