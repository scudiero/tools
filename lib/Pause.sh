## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.14" # -- dscudiero -- Fri 08/06/2018 @ 09:17:49
#===================================================================================================
# Pause execution
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function Pause {
	myIncludes="StringFunctions"
	Import "$myIncludes"
	local ans
	local callerData="$(caller)"
	local lineNo="$(basename $(cut -d' ' -f2 <<< $callerData))/$(cut -d' ' -f1 <<< $callerData)"
	if [[ "$*" != '' ]]; then
		echo -e "${colorGreen}$*\n${colorDefault}"
	else echo -e "${colorGreen}*** Script ($myName) execution paused at $lineNo, please press enter to continue (x to quit, d for debug) ***${colorDefault}\n";
	fi

	ans='junk'
	while [[ $ans != '' ]]; do
		unset ans; read ans; ans=$(Lower ${ans:0:1});
		[[ "$ans" == 'x' ]] && { verboseLevel=0; Goodbye 'quickquit'; }
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
## 06-22-2017 @ 12.04.50 - ("2.0.10")  - dscudiero - Add caller and callers line number to the prompt
## 06-23-2017 @ 08.27.31 - ("2.0.11")  - dscudiero - Only add the caller info if no string was passed in
## 06-08-2018 @ 09:29:28 - 2.0.14 - dscudiero - Set verboseLevel=0 if the user is bailing
## 06-27-2018 @ 12:13:28 - 2.0.14 - dscudiero - Comment out the version= line
