## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.15" # -- dscudiero -- Fri 09/01/2017 @  8:17:43.36
#===================================================================================================
# Get a sting of a char repeated n times
# PadChar <char> <count>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function PadChar { PadString $*; return 0; } #PadChar
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
