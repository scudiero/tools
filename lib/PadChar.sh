## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:43:27.95
#===================================================================================================
# Get a sting of a char repeated n times
# PadChar <char> <count>
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function PadChar {

	local char="$1"; shift
	local len=$1
	local re='^[0-9]+$'
	#[[ $len -eq 0 ]] && echo '' && return 0

	[[ ${char:1} =~ $re ]] && len=$char && unset char
	[[ $char == '' ]] && char='='

	if [[ $len == '' ]]; then
		[[ $TERM == 'xterm' ]] && len=$(stty size </dev/tty | cut -d' ' -f2) || len=80
	fi

	echo "$(head -c $len < /dev/zero | tr '\0' "$char")"
	return 0
} #PadChar
export -f PadChar

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:01 CST 2017 - dscudiero - General syncing of dev to prod
