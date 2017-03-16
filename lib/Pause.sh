## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.7" # -- dscudiero -- 03/16/2017 @ 12:54:01.38
#===================================================================================================
# Pause execution
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Pause {
	local ans
	if [[ "$*" != '' ]]; then
		echo -e "${colorGreen}$*\n${colorDefault}"
	else echo -e "${colorGreen}*** Script ($myName) execution paused, please press enter to continue (x to quit, d for debug) ***${colorDefault}\n";
	fi

	ans='junk'
	while [[ $ans != '' ]]; do
		unset ans; read ans; ans=$(Lower ${ans:0:1});
		[[ "$ans" == 'x' ]] && Goodbye 'quickquit'
		[[ "$ans" == '?' ]] && echo -e "Stack trace:" && echo -e '\t%s\n' "${FUNCNAME[@]}"
		[[ "$ans" == 'v' ]] && set -xv
	done

	return 0
} #Pause
export -f Pause

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 12:52:21 CST 2017 - dscudiero - Added debug code
## Wed Jan  4 13:05:47 CST 2017 - dscudiero - remove debug statemetns
## Wed Jan  4 13:54:06 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Mar 16 12:59:42 CDT 2017 - dscudiero - Switch to use echo vs printf
