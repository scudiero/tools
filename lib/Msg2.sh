## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.56" # -- dscudiero -- Thu 08/03/2017 @  8:41:01.82
#===================================================================================================
# Print/Log formatted messages
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#===================================================================================================
# Display a message with optional logging,
#	if global variable $quiet is true then do not display message
#	if global variable $logit is true then write message out to the global variable $logfile
#
#	'<msgType>,<msgLevel>,<msgTabs>,<msgMode>,<msgFold>'
#	<msgType> in {'-','Note','Info','Warning','Error','Terminate','Verbose'}, default is '-'
#	<msgLevel> in {'-','#number'} where #number is a integer, defaout is '0'
#	<msgTabs> in {'-','#number'} where #number is a integer which can be prefixed with a '+' or '-',
#				default is '+0'
#	<msgMode> in {'-','Screen','Log','Both'}; default is 'Screen'
#	<msgFold> in {'-','true','false'}; default is 'true'
#
# e.g.
# SetIndent 0 ## Set indent level at zero
# Msg2 "This is a normal message without any controls 2This is a normal message without any controls"
# Msg2 $NT "This is a normal message indented once"
# SetIndent 1 ## Set indent level at one
# Msg2 $IT2 "This is an^info message indented twice beyond indent level"
# SetIndent '-1' ## Set indent level in one
# Msg2 $NT1 "This is an note message indented once"
# Msg2 $E$MsgNoFold "This is an error, do not fold the message This is an error, do not fold the message"
# Msg2 $T "This is a terminating message"
#
#===================================================================================================
## Msg2 Shortcuts for typical message control codes,e.g. $N or $NT2
MsgNoFold=',false'
MsgFold=',true'
for msgType in 'N' 'I' 'W' 'E' 'T' 'V'; do
	eval ${msgType}=\'${msgType},-,-,S\'
	eval ${msgType}1=\'${msgType},1,-,S\'
	eval ${msgType}2=\'${msgType},2,-,S\'
	eval ${msgType}3=\'${msgType},3,-,S\'
	eval ${msgType}4=\'${msgType},4,-,S\'
	eval ${msgType}T=\'${msgType},-,+1,S\'
	eval ${msgType}T1=\'${msgType},-,+1,S\'
	eval ${msgType}T2=\'${msgType},-,+2,S\'
	eval ${msgType}T3=\'${msgType},-,+3,S\'
done

## Helper functions to short cut the call
	function MsgNONL 	{ Msg2 'NONL' "$*"; }
	function MsgNoCRLF 	{ Msg2 'NONL' "$*"; }

	function TerminateMsg 	{
		local msgLevel=0 ; local tabLevel=0 ;
		[[ $(IsNumeric "$1") == true ]] && msgLevel=$1 && shift ; [[ $(IsNumeric "$1") == true ]] && tabLevel=$1 && shift;
		local token="${FUNCNAME:0:1},$msgLevel,$tabLevel"
		Msg2 "$token" "$*"
	}
	function Terminate { TerminateMsg $*; }

	function ErrorMsg 	{
		local msgLevel=0 ; local tabLevel=0 ;
		[[ $(IsNumeric "$1") == true ]] && msgLevel=$1 && shift ; [[ $(IsNumeric "$1") == true ]] && tabLevel=$1 && shift;
		local token="${FUNCNAME:0:1},$msgLevel,$tabLevel"
		Msg2 "$token" "$*"
	}
	function Error { ErrorMsg $*; }

	function WarningMsg 	{
		local msgLevel=0 ; local tabLevel=0 ;
		[[ $(IsNumeric "$1") == true ]] && msgLevel=$1 && shift ; [[ $(IsNumeric "$1") == true ]] && tabLevel=$1 && shift;
		local token="${FUNCNAME:0:1},$msgLevel,$tabLevel,-,-"
		Msg2 "$token" "$*"
	}
	function Warning { WarningMsg $*; }

	function InfoMsg 	{
		local msgLevel=0 ; local tabLevel=0 ;
		[[ $(IsNumeric "$1") == true ]] && msgLevel=$1 && shift ; [[ $(IsNumeric "$1") == true ]] && tabLevel=$1 && shift;
		local token="${FUNCNAME:0:1},$msgLevel,$tabLevel"
		Msg2 "$token" "$*"
	}
	function Info { InfoMsg $*; }

	function NoteMsg 	{
		local msgLevel=0 ; local tabLevel=0 ;
		[[ $(IsNumeric "$1") == true ]] && msgLevel=$1 && shift ; [[ $(IsNumeric "$1") == true ]] && tabLevel=$1 && shift;
		local token="${FUNCNAME:0:1},$msgLevel,$tabLevel"
		Msg2 "$token" "$*"
	}
	function Note { NoteMsg $*; }

	function VerboseMsg 	{
		local msgLevel=0 ; local tabLevel=0 ;
		[[ $(IsNumeric "$1") == true ]] && msgLevel=$1 && shift ; [[ $(IsNumeric "$1") == true ]] && tabLevel=$1 && shift;
		local token="${FUNCNAME:0:1},$msgLevel,$tabLevel"
		Msg2 "$token" "$*"
	}
	function Verbose { VerboseMsg $*; }

## Set global indention level
function SetIndent {
	local indent=$1
	[[ $indentLevel == '' ]] && indentLevel=0
	if [[ ${indent:0:1} == '+' || ${indent:0:1} == '-' ]]; then
		let indentLevel=${indentLevel}${indent:0:1}${indent:1}
	else
		indentLevel=$indent
	fi
	return 0
}

## Print / Log the message
function Msg2 {
	[[ $quiet == true ]] && return 0
	PushSettings "$FUNCNAME"
	set +xv # Turn off trace
	SetFileExpansion 'off'

	## Sub function to to the actual output
	function Msg2WriteIt {
		[[ $msgNewLine == true ]] && echoArg='-e' || echoArg='-e -n'
		[[ $msgMode == 'S' || $msgMode = 'B' ]] && [[ $quiet != true ]] && echo $echoArg "$*"
		[[ $msgMode == 'L' || $msgMode = 'B' || $logit == true ]] && echo $echoArg "$*" >> $logFile
		return 0
	}

	local msgCtrl
	[[ ${#*} -gt 1 ]] && msgCtrl="$1" && shift
	local msgText="$*"
	[[ $msgCtrl == '' ]] && msgCtrl='normal,0,+0,S,true'
	local terminateProcessing=false
	[[ $indentLevel == '' ]] && indentLevel=0
	[[ $tabStr = '' ]] && tabStr="$(PadChar ' ' 5)"
	local msgType msgLevel msgTabs msgMode msgFold msgNewLine=true
	unset msgType msgLevel msgTabs msgMode msgFold
	#dump -4 -n msgText -t msgCtrl

	## Parse control string
	local numTokens=1; for (( tCntr=0; tCntr<=${#msgCtrl}; tCntr++ )); do [[ ${msgCtrl:$tCntr:1} == ',' ]] && let numTokens=numTokens+1; done
	msgType="$(Upper "$(cut -d',' -f1 <<< $msgCtrl)")"
	#dump -4 -t msgType
	[[ $numTokens -gt 1 ]] && msgLevel=$(cut -d',' -f2 <<< $msgCtrl)
	[[ $numTokens -gt 2 ]] && msgTabs=$(cut -d',' -f3 <<< $msgCtrl)
	[[ $numTokens -gt 3 ]] && msgMode=$(cut -d',' -f4 <<< $msgCtrl)
	[[ $numTokens -gt 4 ]] && msgFold=$(cut -d',' -f5 <<< $msgCtrl)
	#dump -4 -t msgType msgTabs msgMode msgFold msgText

	[[ $msgType == '.' || $msgType  == '-' || $msgType  == '' ]] && msgType='NORMAL'
	[[ $msgType != 'NORMAL' && $msgType != 'NONL' ]] && msgType=$(Upper ${msgType:0:1})
	[[ $msgLevel == '-' || $msgLevel == '.' || $msgLevel == '' ]] && msgLevel=0
	[[ $msgTabs  == '-' || $msgTabs  == '.' || $msgTabs  == '' ]] && msgTabs='+0'
	[[ $msgMode  == '-' || $msgMode  == '.' || $msgMode  == '' ]] && msgMode='S' || msgMode=$(Upper ${msgMode:0:1})
	[[ $msgFold  == '-' || $msgFold  == '.' || $msgFold  == '' ]] && msgFold=true

	[[ $verboseLevel -ge 4 ]] && echo -e '\tmsgLevel = >'$msgLevel'<'
	#dump -4 -t msgType msgTabs msgMode msgFold msgText

	## Check to see if we should just quit
	if [[ $msgLevel != '' && $msgLevel -gt $verboseLevel ]] || [[ $quiet == true && $msgMode != 'L' && $msgMode != 'B' ]]; then
		SetFileExpansion
		PopSettings "$FUNCNAME"
		return 0
	fi

	## Set prefix
	local msgPrefix=''
	local msgSuffix=''
	local subtractFactor=0
	local tempStr=$(ColorI)
	local subtractor1=${#tempStr}
	local tempStr=$(ColorT)
	local subtractor2=${#tempStr}

	if [[ $msgType == 'N' ]]; then
		msgPrefix="$(ColorI "*Note*") -- " ; subtractFactor=$subtractor1
	elif [[ $msgType == 'I' ]]; then
		msgPrefix="$(ColorI "*Info*") -- " ; subtractFactor=$subtractor1
	elif [[ $msgType == 'W' ]]; then
		msgPrefix="$(ColorW "*Warning*") -- " ; subtractFactor=$subtractor1 ; [[ $allowAlerts != true || $batchMode != true ]] && msgSuffix="\a"
	elif [[ $msgType == 'E' ]]; then
		msgPrefix="$(ColorE "*Error*") -- " ; subtractFactor=$subtractor1 ; [[ $allowAlerts != true || $batchMode != true ]] && msgSuffix="\a\a"
	elif [[ $msgType == 'T' ]]; then
		msgPrefix="\n$(ColorT "*Fatal Error*") ($myName) -- " ; subtractFactor=$subtractor2 ; terminateProcessing=true ; [[ $allowAlerts != true || $batchMode != true ]] && msgSuffix="\a\a\a"
	elif [[ $msgType == 'V' ]]; then
		msgText="$(ColorV "$msgText")" ; subtractFactor=$subtractor1
	elif [[ $msgType == 'NONL' ]]; then
		msgNewLine=false
	fi

	## If warning or error add to message accumulators
	[[ $msgType == 'W' ]] && warningMsgsIssued=true && warningMsgs+=("$(sed s"/\^//g" <<< "${msgPrefix}${msgText}")")
	[[ $msgType == 'E' || $msgType == 'T' ]] && errorMsgsIssued=true && errorMsgs+=("$(sed s"/\^//g" <<< "${msgPrefix}${msgText}")")

	## Add tabs based on global indentLevel value plus message tabs value
	let msgTabs=${indentLevel}${msgTabs:0:1}${msgTabs:1}
	local tabCntr; for ((tabCntr = 0 ; tabCntr < $msgTabs; tabCntr++)); do msgPrefix="${tabStr}${msgPrefix}"; done

	## Construct message
	msgText="${msgPrefix}${msgText}${msgSuffix}"

	## Convert '^' chars to tabStr
	msgText="$(sed s"/\^/$tabStr/g" <<< "$msgText")"

	## Set screenwidth
	local screenWidth=80
	[[ $TERM == 'xterm' ]] && screenWidth=$(stty size </dev/tty | cut -d' ' -f2) || msgFold=false
	#dump -4 -t screenWidth msgFold #;echo -e '\t${#msgText} = >'${#msgText}'<'

	## Display / log message
	if [[ $msgFold == false || ${#msgText} -le $screenWidth ]]; then
		Msg2WriteIt "$msgText"
	else
		## Find breakpoint for the first line and print
		local cutAt
		let cutAt=$screenWidth+$subtractFactor-2
		local nextChar=${msgText:$cutAt:1}
		if [[ $nextChar != '' ]]; then
			for ((cutAt = $cutAt ; cutAt > 0 ; cutAt--)); do
			  [[ ${msgText:$cutAt:1} == ' ' ]] && break
			done
		fi
		[[ $cutAt -le 0 ]] && cutAt=$screenWidth
		Msg2WriteIt "${msgText:0:$cutAt+1}"
		msgText=${msgText:$cutAt+1}

		## process the remaining text using the fold command
		local tmpFile=$(mkTmpFile "$FUNCNAME")
		let foldCols=$screenWidth-${#msgPrefix}
		let padLen=${#msgPrefix}-$subtractFactor
		padStr=$(PadChar ' ' $padLen)
		fold -sw $foldCols <<< $(echo "$msgText") > $tmpFile
		while read -r line; do
			Msg2WriteIt "${padStr}${line}"
		done < $tmpFile
		rm -f $tmpFile
	fi

	SetFileExpansion
	PopSettings "$FUNCNAME"
	## Quit if terminating message
	[[ $terminateProcessing == true ]] && Msg2 && Goodbye -1

	return 0
} # Msg2
export -f Msg2 TerminateMsg ErrorMsg WarningMsg InfoMsg NoteMsg VerboseMsg MsgNONL MsgNoCRLF
export -f Terminate Error Warning Info Note Verbose

#===================================================================================================
# Checkin Log
#===================================================================================================
## Wed Jan  4 13:34:04 CST 2017 - dscudiero - comment out the 'version=' line
## Thu Feb  9 08:06:34 CST 2017 - dscudiero - make sure we are using our own tmpFile
## Thu Mar 16 08:13:40 CDT 2017 - dscudiero - Quit immediataly if quiet is true
## Mon Mar 20 08:07:34 CDT 2017 - dscudiero - Comment out Dump commands - trying to speed thing up
## 05-16-2017 @ 06.43.01 - ("2.0.55")  - dscudiero - Add script name to fatal error messages
## 08-03-2017 @ 08.47.54 - ("2.0.56")  - dscudiero - Add different alert counts based on message severity
