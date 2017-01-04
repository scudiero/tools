## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:35:38.58
#===================================================================================================
# Ring the bell
# Alert <#ofAlerts> <sleepTime>
# Defaults: 5 1
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Alert {
	[[ $batchMode == true || $quiet == true ]] && return 0
	local numAlerts=$1; shift || true
	if [[ $numAlerts != '' && $(IsNumeric $numAlerts) == false ]]; then
	 [[ $numAlerts == 'on' ]] && allowAlerts=true || allowAlerts=false
	 return 0
	fi

	if [[ $numAlerts = '' ]]; then numAlerts=4; fi
	local sleepTime=$1
	if [[ $sleepTime = '' ]]; then sleepTime=1; fi
   local cntr=1
	until [  $cntr -gt $numAlerts ]; do
		printf "\a";
		sleep $sleepTime;
		let cntr=cntr+1
	done

	return 0
} #Alert
export -f Alert

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:47 CST 2017 - dscudiero - General syncing of dev to prod
