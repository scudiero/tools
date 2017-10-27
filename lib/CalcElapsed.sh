## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.9" # -- dscudiero -- Fri 10/27/2017 @  8:04:29.85
#===================================================================================================
# Calculate Elapsed time
# CalcElapsed startTime [endTime]
# echos the elapsed time to stdout
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CalcElapsed {
	local startTime="$1"
	[[ -z $startTime ]] && return 0
	local endTime="${2:-$(date +%s)}"
	local elapTime; unset elapTime

	local elapSeconds=$(( endTime - startTime ))
	local eHr=$(( elapSeconds / 3600 ))
	local elapSeconds=$(( elapSeconds - eHr * 3600 ))
	local eMin=$(( elapSeconds / 60 ))
	local elapSeconds=$(( elapSeconds - eMin * 60 ))

	echo "$(printf "%02dh %02dm %02ds" $eHr $eMin $elapSeconds)"
	return 0
} #CalcElapsed
export -f CalcElapsed

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:52 CST 2017 - dscudiero - General syncing of dev to prod
## 10-27-2017 @ 08.05.05 - ("2.0.9")   - dscudiero - Return results by echoing to stdout
