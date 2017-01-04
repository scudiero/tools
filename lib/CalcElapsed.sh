## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:36:05.06
#===================================================================================================
# Calculate Elapsed time
# CalcElapsedTime startTime endTime
# Sets variable elapsedTime
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CalcElapsed {
	startTime="$1"
	endTime="$2"
	if [[ "$endTime" = "" ]]; then
		date=$(date)
		endTime=$(date +%s)
	fi

	elapTime=''
	elapSeconds=$(( endTime - startTime ))
	eHr=$(( elapSeconds / 3600 ))
	elapSeconds=$(( elapSeconds - eHr * 3600 ))
	eMin=$(( elapSeconds / 60 ))
	elapSeconds=$(( elapSeconds - eMin * 60 ))
	elapTime=$(printf "%02dh %02dm %02ds" $eHr $eMin $elapSeconds)

	return 0
} #CalcElapsed
export -f CalcElapsed

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:52 CST 2017 - dscudiero - General syncing of dev to prod
