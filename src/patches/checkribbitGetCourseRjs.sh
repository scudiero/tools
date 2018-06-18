#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#=======================================================================================================================
#= Description #========================================================================================================
# See 'scriptDescription' below
# Note: This script cannot be run standalone, it is meant to be sourced by the courseleafPatch script
# Note: This file is sourced by the courseleafPatch script, please be careful
#=======================================================================================================================
scriptDescription="Check /web/ribbit/getcourse.rjs file"

checkFile="$tgtDir/web/ribbit/getcourse.rjs"
if [[ -f "$checkFile" ]]; then
	Msg; Msg "^$CPitemCntr) $scriptDescription..."
	skelDate=$(date +%s -r ${skeletonRoot}/release/web/ribbit/getcourse.rjs)
	fileDate=$(date +%s -r $tgtDir/web/ribbit/getcourse.rjs)
	if [[ $skelDate -gt $fileDate ]]; then
		text="The time date stamp of the file '$tgtDir/web/ribbit/getcourse.rjs'\n\tis less "
		text="$text than the time date stamp of the file in the skeleton, you should compare the files and merge"
		text="$text \n\tany required changes into  sites file."
		Warning 0 1 "$text"
	fi
	((CPitemCntr++))
fi

#=======================================================================================================================
## Check-in Log
#=======================================================================================================================
## 06-18-2018 @ 08:28:24 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 08:30:48 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
## 06-18-2018 @ 15:50:19 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
