## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 01/04/2017 @ 12:49:01.09
#===================================================================================================
# Pause execution
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Pause {
	local ans
	if [[ "$*" != '' ]]; then
		printf "${colorGreen}$*\n${colorDefault}"
	else printf "${colorGreen}*** Script ($myName) execution paused, please press enter to continue (x to quit, d for debug) ***${colorDefault}\n";
	fi

	ans='junk'
[[ $DEBUG == true ]] && Here P0 && dump ans
	while [[ $ans != '' ]]; do
[[ $DEBUG == true ]] && Here P1 && dump ans
		unset ans; read ans; ans=$(Lower ${ans:0:1});
[[ $DEBUG == true ]] && Here P2 && dump ans
		[[ "$ans" == 'x' ]] && Goodbye 'quickquit'
		[[ "$ans" == '?' ]] && echo -e "Stack trace:" && printf '\t%s\n' "${FUNCNAME[@]}"
		[[ "$ans" == 'v' ]] && set -xv
	done

[[ $DEBUG == true ]] && Here P9 && dump ans
	return 0
} #Pause
export -f Pause

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 12:52:21 CST 2017 - dscudiero - Added debug code
