## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.12" # -- dscudiero -- 12/07/2016 @  8:07:47.06
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

