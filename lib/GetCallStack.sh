## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.13" # -- dscudiero -- 01/04/2017 @ 13:38:55.14
#===================================================================================================
# Returns (echo) a formatted string of the call stack to the currently executing module
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function GetCallStack {
	local callStack; unset callStack
	for ((i=${#FUNCNAME[@]}-1; i >= 1; i--)); do
		[[ $i -eq ${#FUNCNAME[@]}-1 ]] && callStack="${BASH_SOURCE[$i]}/${FUNCNAME[$i]} (${BASH_LINENO[$i]})" || \
										callStack="$callStack, ${BASH_SOURCE[$i]}/${FUNCNAME[$i]} (${BASH_LINENO[$i]})"
	done;
	callStack="$(sed s"#$TOOLSPATH#\$TOOLSPATH#g" <<< $callStack)"
	callStack="$(sed s"#$HOME#\$HOME#g" <<< $callStack)"
	echo "$callStack"
} #GetCallStack
export -f GetCallStack

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:28 CST 2017 - dscudiero - General syncing of dev to prod
