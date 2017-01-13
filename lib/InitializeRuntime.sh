## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.72" # -- dscudiero -- 01/13/2017 @ 15:25:09.90
#===================================================================================================
# Initialize the tools runtime environment
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

TrapSigs 'on'

GD echo -e "\n=== Starting InitializeRuntime ========================================================================"

unset helpSet helpNotes warningMsgs errorMsgs summaryMsgs myRealPath myRealName changeLogRecs parsedArgStr

## Make sure we have avalue for TERM
[[ $TERM == '' ]] && export TERM=xterm
shopt -s checkwinsize
set -e  # Turn ON Exit immediately
#set +e  # Turn OFF Exit immediately

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
	defaultsLoaded=false
	GetDefaultsData
	SetFileExpansion

## Set default colors
	if [[ $TERM != 'dumb' ]]; then
		colorWhite='\e[97m'
		colorBlack='\e[30m'
		colorRed='\e[31m'
		colorBlue='\e[34m'
		colorGreen='\e[32m'
		colorCyan='\e[36m'
		colorMagenta='\e[35m'
		colorPurple="$colorMagenta"
		colorOrange='\e[33m'
		colorGrey='\e[90m'
		colorDefault='\e[0m'
		#colorDefaultVal='\e[0;4;90m #0=normal, 4=bold,90=foreground
		colorDefaultVal=$colorMagenta #0=normal, 4=bold,90=foreground
		colorTerminate='\e[1;97;101m' #1=bold, 97=foreground, 41=background
		colorFatalError="$colorTerminate"
		#colorTerminate='\e[1;31m'

		#backGroundColorRed='\e[41m'
		#colorTerminate=${backGroundColorRed}${colorWhite}
		colorError=$colorRed
		colorWarn=$colorMagenta
		colorKey=$colorGreen
		#colorKey=$colorMagenta
		colorWarning=$colorWarn
		colorInfo=$colorGreen
		colorNote=$colorGreen
		colorVerbose=$colorGrey
		colorMenu=$colorGreen
	else
		unset colorRed colorBlue colorGreen colorCyan colorMagenta colorOrange colorGrey colorDefault
		unset colorTerminate colorError colorWarn colorWarning
		noNews=true
	fi

	function ColorE { local string="$*"; echo "${colorError}${string}${colorDefault}"; }

## If the user has a .tools file then read the values into a hash table
[[ $userName == 'dscudiero' ]] && echo "allowedUserVars = >$allowedUserVars<"
	if [[ -r "$HOME/tools.cfg" && ${myRhel:0:1} -gt 5 ]]; then
		ifs="$IFS"; IFS=$'\n'; while read -r line; do
			line=$(tr -d '\011\012\015' <<< "$line")
			[[ -z $line || ${line:0:1} == '#' ]] && continue
			vName=$(cut -d'=' -f1 <<< "$line"); [[ $vName == '' ]] && $(cut -d':' -f1 <<< "$line")
			[[ $(Contains ",${allowedUserVars}," ",${vName},") == false ]] && Msg2 $E "Variable '$vName' not allowed in tools.cfg file, setting will be ignored" && continue
			vValue=$(cut -d'=' -f2 <<< "$line"); [[ $vName == '' ]] && $(cut -d':' -f2 <<< "$line")
			eval $vName=\"$vValue\"
		done < "$HOME/tools.cfg"
		IFS="$ifs"
	fi

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
	# for token in D K I N W E T V M; do
	# 	#echo "\$(Color$token \"This is Color '$token'\")"
	# 	eval "echo -e \"\t$(Color$token \"This is Color '$token'\")\""
	# done

## Set forking limit
	maxForkedProcesses=$maxForkedProcessesPrime
	[[ $scriptData3 != '' && $(IsNumeric $scriptData3) == true ]] && maxForkedProcesses=$scriptData3
	hour=$(date +%H)
	hour=${hour#0}
	[[ $hour -ge 20 && $maxForkedProcessesAfterHours -gt $maxForkedProcesses ]] && maxForkedProcesses=$maxForkedProcessesAfterHours
	[[ -z $maxForkedProcesses ]] && maxForkedProcesses=3

export FRAMEWORKLOADED=true
GD echo -e "\n=== Stopping InitializeRuntime ========================================================================"

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
