#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.2" # -- dscudiero -- 01/04/2017 @ 13:37:05.14
#===================================================================================================
# $callPgmName "$executeFile" ${executeFile##*.} "$libs" $scriptArgs
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CheckSemaphore {
	##==============================================================================================
	IfMe echo ">>> $FUNCNAME -- Starting: \$* = '$*' <<<"
	local callPgmName=$1; shift
	local waitOn=$1; shift
	local lib=$1; shift
	local okToRun okToRunWaiton semaphoreId
	IfMe dump -t callPgmName
	##==============================================================================================

	unset okToRun okToRunWaiton
	okToRun=$(Semaphore 'check' $callPgmName)
	## Check to see if we are running or any waitOn process are running
	[[ $okToRun == false && $(Contains ",$waitOn," ',self,') != true ]] && Msg2 $T "CallPgm: Another instance of this script ($callPgmName) is currently running.\n"
	if [[ $waitOn != '' ]]; then
		for pName in $(echo $waitOn | tr ',' ' '); do
			waitonMode=$(cut -d':' -f2 <<< $pName)
			pName=$(cut -d':' -f1 <<< $pName)
			[[ $(Lower $waitonMode) == 'g' ]] && checkAllHosts='checkAllHosts' || unset checkAllHosts
			okToRun=$(Semaphore 'check' $pName $checkAllHosts)
			if [[ $okToRun == false ]]; then
				[[ $batchMode != true ]] && Msg2 "CallPgm: Waiting for process '$pName' to finish..."
				Semaphore 'waiton' "$pName" $checkAllHosts
			fi
		done
	fi
	## Set our semaphore
	semaphoreId=$(Semaphore 'set')
	GD echo -e "\t semaphoreId: $semaphoreId"

	echo $semaphoreId
	return 0
} #CheckSemaphore
export -f CheckSemaphore

#===================================================================================================
# Checkin Log
#===================================================================================================
## Wed Jan  4 13:53:00 CST 2017 - dscudiero - General syncing of dev to prod
