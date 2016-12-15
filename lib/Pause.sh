## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.3" # -- dscudiero -- 11/07/2016 @ 14:45:39.08
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
	while [[ $ans != '' ]]; do
		unset ans; read ans; ans=$(Lower ${ans:0:1});
		[[ "$ans" == 'x' ]] && Goodbye 'quickquit'
		[[ "$ans" == '?' ]] && echo -e "Stack trace:" && printf '\t%s\n' "${FUNCNAME[@]}"
		[[ "$ans" == 'v' ]] && set -xv
	done

	return 0
} #Pause
export -f Pause

#===================================================================================================
# Check-in Log
#===================================================================================================
