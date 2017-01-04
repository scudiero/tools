## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.10" # -- dscudiero -- 01/04/2017 @ 13:50:18.18
#===================================================================================================
# Turn signal process off
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function TrapSigs {
	local mode=${1: -on}

	if [[ $mode == 'on' ]]; then
		trap 'SignalHandeler ERR ${LINENO} ${?}' ERR
		trap 'SignalHandeler SIGINT ${LINENO} ${?}' SIGINT
		trap 'SignalHandeler SIGTERM ${LINENO} ${?}' SIGTERM
		trap 'SignalHandeler SIGQUIT ${LINENO} ${?}' SIGQUIT
		trap 'SignalHandeler SIGHUP ${LINENO} ${?}' SIGHUP
		trap 'SignalHandeler SIGABRT ${LINENO} ${?}' SIGABRT
		trap 'SignalHandeler SIGHUP ${LINENO} ${?}' SIGHUP
	else
		trap - ERR SIGINT SIGTERM SIGQUIT SIGHUP SIGABRT SIGHUP
	fi

	return 0
} #TrapSigs
export -f TrapSigs

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:34 CST 2017 - dscudiero - General syncing of dev to prod
