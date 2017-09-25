## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.2" # -- dscudiero -- Mon 09/25/2017 @  8:05:51.36
#===================================================================================================
# Usage: Msg3 <msgType> <msgLevel> <indentLevel> msgText
# 	msgType: [N,I,W,E,T]
# 	msgLevel: integer
# 	indentLevel: integer
#===================================================================================================
function Msg3 {
	[[ $quiet == true ]] && return 0
	## First token is a type identifier?
		local msgType msgLevel indentLevel msgText
		unset msgType msgLevel indentLevel msgText
		if [[ $# -gt 1 ]]; then
			local re='^[q,Q,n,N,i,I,w,W,e,E,t,T,v,V,l,L]$'
			[[ $1 =~ $re ]] && msgType="$1" && shift 1 || true
			if [[ -n $msgType ]]; then
				## First/Next token is a msg level?
				re='^[0-9]+$'
				if [[ $1 =~ $re ]]; then
					[[ $1 -gt $verboseLevel ]] && return 0
					msgLevel="$1"
					shift 1 || true
				fi
				## Next token is a indent level?
				re='^[0-9]+$'
				[[ $1 =~ $re ]] && indentLevel="$1" && shift 1 || true
			fi
			#dump msgType msgLevel indentLevel msgText

			## Format message
			msgText="$*"
			case $msgType in
				q|Q) echo -e "$msgText" && return 0 ;;
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
		## If the string has '^'s then expand them
		[[ "${msgText#*\^}" != "$msgText" ]] && msgText="$(sed s"/\^/$tabStr/g" <<< "$msgText")"
		echo -e "$msgText"

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
export -f Msg Info Note Warning Error Terminate Verbose Quick Log## 09-25-2017 @ 08.03.42 - ("1.0.1")   - dscudiero - General syncing of dev to prod
## 09-25-2017 @ 08.06.13 - ("1.0.2")   - dscudiero - General syncing of dev to prod
