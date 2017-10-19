## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.32" # -- dscudiero -- Thu 10/19/2017 @  8:57:22.44
#===================================================================================================
# Usage: Msg3 <msgType> <msgLevel> <indentLevel> msgText
# 	msgType: [N,I,W,E,T]
# 	msgLevel: integer
# 	indentLevel: integer
#===================================================================================================
function Msg3 {
	[[ $quiet == true ]] && return 0
	[[ $# -eq 0 ]] && echo && return 0
	Import "Colors"
	## First token is a type identifier?
		local msgType msgLevel indentLevel msgText
		unset msgType msgLevel indentLevel msgText
		if [[ $# -gt 1 ]]; then
			[[ $1 = 'Q' || $1 = 'q' ]] && shift && echo -e "$*" && return 0
			local re='^[q,Q,n,N,i,I,w,W,e,E,t,T,v,V,l,L]$'
			[[ $1 =~ $re ]] && msgType="$1" && shift 1 || true
			if [[ -z $msgLevel ]]; then
				## First/Next token is a msg level?
				re='^[0-9]+$'
				if [[ $1 =~ $re ]]; then
					[[ $1 -gt $verboseLevel ]] && return 0
					msgLevel="$1"
					shift 1 || true
				fi
			fi
			## Next token is a indent level?
			if [[ -z $indentLevel ]]; then
				re='^[0-9]+$'
				[[ $1 =~ $re ]] && indentLevel="$1" && shift 1 || true
			fi
dump msgType msgLevel indentLevel

			## Format message
			msgText="$*"
			case $msgType in
				n|N) msgText="$(ColorN "*Note*") -- $msgText" ;;
				i|I) msgText="$(ColorI "*Info*") -- $msgText" ;;
				w|W) msgText="$(ColorW "*Warning*") -- $msgText\a" ;;
				e|E) msgText="$(ColorE "*Error*") -- $msgText\a" ;;
				t|T) msgText="$(ColorT "*Fatal Error*") -- $msgText\a" ;;
				v|V) msgText="$(ColorV)$msgText" ;;
				l|L) [[ -n $logFile && -w $logFile ]] && echo -e "$msgText" >> $logFile
					 return 0 ;;
			esac

			## Add indention
			if [[ -n $indentLevel && $indentLevel -gt 0 ]]; then
				local tmpStr=$(echo "$(head -c $indentLevel < /dev/zero | tr '\0' "^")")
				msgText="${tmpStr}${msgText}"
			fi
		else
			msgText="$*"
		fi

	## print message
		#[[ "${msgText#*\^}" != "$msgText" ]] && msgText="$(sed s"/\^/$tabStr/g" <<< "$msgText")"
		[[ -z $tabStr ]] && tabStr='     '
		[[ "${msgText#*\^}" != "$msgText" ]] && msgText="${msgText//^/$tabStr}" ## Expand tab chars

		echo -e "$msgText"
		#[[ -n $logFile && -w $logFile ]] && echo -e "$msgText" >> "$logFile"&
		[[ $msgType == 'T' ]] && Goodbye 3

	return 0
}
export -f Msg3

#===================================================================================================
## Helper functions
function Msg { Msg3 $* ; return 0; }
function Info { Msg3 "I" $* ; return 0; }
function Note { Msg3 "N" $* ; return 0; }
function Warning { Msg3 "W" $* ; return 0; }
function Error { Msg3 "E" $* ; return 0; }
function Terminate { Msg3 "T" $* ; return 0; }
function Verbose { Msg3 "V" $* ; return 0; }
function Quick { Msg3 "Q" $* ; return 0; }
function Log { Msg3 "L" $* ; return 0; }
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
