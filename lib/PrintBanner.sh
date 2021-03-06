## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:45:14.44
#===================================================================================================
# Print a banner
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function PrintBanner {
	local centerText=$*
	local centerPad printStr len
	local horizontalLine="$(PadChar)"
	echo "$horizontalLine"
	[[ $TERM == 'xterm' ]] && len=$(stty size </dev/tty | cut -d' ' -f2) || len=80
	if [[ ${#centerText} -ge $len ]]; then
		printStr="$centerText"
	else
		let centerPad=$len-2-${#centerText}; let centerPad=$centerPad/2
		printStr="=$(PadChar ' ' ${centerPad})${centerText}$(PadChar ' ' ${centerPad})     "
		printStr=${printStr:0:$len-1}
	fi
	echo -e "${printStr}="
	echo "$horizontalLine"

	return 0
} #PrintBanner
export -f PrintBanner

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:09 CST 2017 - dscudiero - General syncing of dev to prod
