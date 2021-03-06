## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.20" # -- dscudiero -- Thu 04/26/2018 @ 12:48:21.08
#===================================================================================================
# Get a sting of a char repeated n times
# PadChar <char> <count>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function PadChar {
	local char="$1"; shift || true
	local len=$1
	local re='^[0-9]+$'
	#[[ -z $len || $len -eq 0 ]] && echo '' && return 0

	[[ ${char:1} =~ $re ]] && len=$char && unset char
	[[ -z $char ]] && char='='

	if [[ -z $len ]]; then
		[[ $TERM == 'xterm' ]] && len=$(stty size </dev/tty | cut -d' ' -f2) || len=80
	fi

	echo "$(head -c $len < /dev/zero | tr '\0' "$char")"
	return 0
} #PadChar
export -f PadChar

function PadString {
	local str="$1"; shift || true
	local len=$1
	local re='^[0-9]+$'

	[[ ${str:1} =~ $re ]] && len=$str && str="$1"
	[[ -z $str ]] && str='='

	if [[ -z $len ]]; then
		[[ $TERM == 'xterm' ]] && len=$(stty size </dev/tty | cut -d' ' -f2) || len=80
	fi
	(( len=$len/${#str} ))

	for ((i=0; i<$len; i++)); do
		echo -n "$str"
	done
	return 0
} #PadString
export -f PadString

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:01 CST 2017 - dscudiero - General syncing of dev to prod
## 09-01-2017 @ 08.18.04 - ("2.0.15")  - dscudiero - Allow the pad char to be a string
## 09-01-2017 @ 09.27.42 - ("2.0.16")  - dscudiero - restore PadChar
## 11-02-2017 @ 10.27.20 - ("2.0.17")  - dscudiero - Initial implimentation
## 04-26-2018 @ 12:49:46 - 2.0.20 - dscudiero - Comment out line where we stop if the len is not set
