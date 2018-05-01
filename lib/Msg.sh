## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.56" # -- dscudiero -- Tue 05/01/2018 @ 11:12:50.84
#===================================================================================================
# Usage: Msg <msgType> <msgLevel> <msgIndent> msgText
# 	msgType: [N,I,W,E,T]
# 	msgLevel: integer
# 	msgIndent: integer
#===================================================================================================
function Msg {
	[[ $quiet == true ]] && return 0
	[[ $# -eq 0 ]] && echo && return 0
	Import "Colors"
	## First token is a type identifier?
		local msgType msgLevel msgIndent msgText
		unset msgType msgLevel msgIndent msgText
		if [[ $# -gt 1 ]]; then
			[[ $1 = 'Q' || $1 = 'q' ]] && shift && echo -e "$*" && return 0
			local re='^[n,N,i,I,w,W,e,E,t,T,v,V,l,L]$'
			[[ ${1#-} =~ $re ]] && msgType="$1" && shift 1 || true
			if [[ -z $msgLevel ]]; then
				## First/Next token is a msg level?
				re='^[0-9]+$'
				if [[ $1 =~ $re ]]; then
					msgLevel="$1"
					shift 1 || true
				fi
			fi
			## Next token is a indent level?
			if [[ -z $msgIndent ]]; then
				re='^[+,-]{0,1}[0-9]$'
				if [[ $1 =~ $re ]]; then 
					msgIndent="$1" && shift 1 || true
					if [[ ${msgIndent:0:1} == '+' ]]; then
						(( msgIndent = indentLevel + ${msgIndent:1} ))
					elif [[ ${msgIndent:0:1} == '-' ]]; then
						(( msgIndent = indentLevel - ${msgIndent:1} ))
					fi
				fi
			fi
		fi
	
	[[ -z $msgIndent && -n $indentLevel ]] && msgIndent=$indentLevel
	[[ $logOnly == true ]] && msgType='L'
	
	dump 4 msgType msgLevel msgIndent
	## Format message
		msgText="$*"

		case $msgType in
			l|L) [[ -n $logFile && -w $logFile ]] && { echo -e "$msgText" >> $logFile; return 0; } ;;
			n|N) msgText="$(ColorN "*Note*") -- $msgText" ;;
			i|I) msgText="$(ColorI "*Info*") -- $msgText" ;;
			w|W) msgText="$(ColorW "*Warning*") -- $msgText\a" ;;
			e|E) msgText="$(ColorE "*Error*") -- $msgText\a" ;;
			t|T) msgText="$(ColorT "*Fatal Error*") -- $msgText\a" ;;
			v|V) [[ $msgLevel -lt $verboseLevel && -n $logFile && -w $logFile ]] && { echo -e "$msgText" >> $logFile; return 0; } 
				msgText="$(ColorV)$msgText" ;;
		esac
		[[ $msgLevel -gt $verboseLevel ]] && return 0

		## Add indention
		if [[ -n $msgIndent && $msgIndent -gt 0 ]]; then
			local tmpStr=$(echo "$(head -c $msgIndent < /dev/zero | tr '\0' "^")")
			msgText="${tmpStr}${msgText}"
		fi

	## print message
		[[ -z $tabStr ]] && tabStr='     '
		msgText="${msgText//^/$tabStr}" ## Expand tab chars
		echo -e "$msgText"
		#[[ -n $logFile && -w $logFile ]] && echo -e "$msgText" >> "$logFile"&
		[[ $msgType == 'T' ]] && Goodbye 3

	return 0
}
export -f Msg

#===================================================================================================
## Helper functions
function Info { Msg "I" $* ; return 0; }
function Note { Msg "N" $* ; return 0; }
function Warning { Msg "W" $* ; return 0; }
function Error { Msg "E" $* ; return 0; }
function Terminate { Msg "T" $* ; return 0; }
function Verbose { Msg "V" $* ; return 0; }
function Quick { Msg "Q" $* ; return 0; }
function Log { Msg "L" $* ; return 0; }
export -f Msg Info Note Warning Error Terminate Verbose Quick Log

#===================================================================================================
## check-in log
#===================================================================================================
## 09-25-2017 @ 08.03.42 - ("1.0.1")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.06.13 - ("1.0.2")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.09.54 - ("1.0.4")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.29.25 - ("1.0.5")   - dscudiero - Quick processing if no arguments passed, just echo and return
## 09-26-2017 @ 07.55.52 - ("1.0.6")   - dscudiero - Move the Quick directive earlier
## 09-26-2017 @ 15.35.34 - ("1.0.7")   - dscudiero - Fix bug with the quick options
## 09-29-2017 @ 06.46.13 - ("1.0.8")   - dscudiero - General syncing of dev to prod
## 10-05-2017 @ 09.06.01 - ("1.0.14")  - dscudiero - switch how we expand tabs to use bash native command
## 10-05-2017 @ 09.42.12 - ("1.0.18")  - dscudiero - General syncing of dev to prod
## 10-11-2017 @ 10.43.22 - ("1.0.19")  - dscudiero - Write message out to the logFile also
## 10-11-2017 @ 10.44.29 - ("1.0.20")  - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 10.49.36 - ("1.0.21")  - dscudiero - check to make sure logFile exists and is writeable before writing
## 10-11-2017 @ 11.11.04 - ("1.0.22")  - dscudiero - Cosmetic/minor change
## 10-11-2017 @ 11.50.11 - ("1.0.23")  - dscudiero - Remove logging to logFile, getting duplicates
## 10-19-2017 @ 07.52.56 - ("1.0.24")  - dscudiero - Fix seting of message level
## 10-19-2017 @ 08.20.48 - ("1.0.31")  - dscudiero - c
## 10-19-2017 @ 09.01.09 - ("1.0.32")  - dscudiero - s
## 10-19-2017 @ 10.35.36 - ("1.0.33")  - dscudiero - Remove debug statements
## 11-09-2017 @ 14.15.05 - ("1.0.34")  - dscudiero - Added NotifyAllApprovers
## 04-02-2018 @ 14:54:57 - 1.0.36 - dscudiero - Make the indentLevel local to function
## 04-02-2018 @ 15:01:42 - 1.0.38 - dscudiero - Allow specificaiton of + or - n for msgIndent
## 04-02-2018 @ 16:21:58 - 1.0.54 - dscudiero - Tweak tabbing
## 04-26-2018 @ 08:32:32 - 1.0.55 - dscudiero - Change debug message levels
## 05-01-2018 @ 11:13:12 - 1.0.56 - dscudiero - Allow '-' in front of message type
