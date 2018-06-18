#!/bin/bash
#DO NOT AUTOVERSION
#=======================================================================================================================
version=1.0.-1 # -- dscudiero -- 10/20/2016 @ 14:58:14.98
#= Description #========================================================================================================
# See 'scriptDescription' below
# Note: This script cannot be run standalone, it is meant to be sourced by the courseleafPatch script
# Note: This file is sourced by the courseleafPatch script, please be careful
#=======================================================================================================================
scriptDescription="Check to see if installed 'special' cgis are still necessary"

## Check to see if there are any 'special' cgis installed, see if they are still necessary
tgtVer="$($tgtDir/web/$courseleafProgDir/$courseleafProgDir.cgi -v 2> /dev/null | cut -d" " -f3)"
for checkDir in tcfdb; do
	if [[ -f $tgtDir/web/$courseleafProgDir/$checkDir/courseleaf.cgi ]]; then
		checkCgiVer="$($tgtDir/web/$courseleafProgDir/$checkDir/$courseleafProgDir.cgi -v 2> /dev/null | cut -d" " -f3)"
		if [[ $(CompareVersions "$checkCgiVer" 'le' "$tgtVer") == true ]]; then
			Msg; Msg "^^Found a 'special' courseleaf cgi directory ($checkDir)\n\tand the version of that cgi ($checkCgiVer) is less than the target version ($tgtVer).\n\tRemoving the directory"
			BackupCourseleafFile "$tgtDir/web/$courseleafProgDir/$checkDir" "$backupRootDir"
			backupFile "$tgtDir/web/$courseleafProgDir/$checkDir" "$backupRootDir"
			rm -f $tgtDir/web/$courseleafProgDir/$checkDir
			changeLogRecs+=("Removed '$tgtDir/web/$courseleafProgDir/$checkDir'")
		fi
	fi
done
## 06-18-2018 @ 08:28:39 - 1.0.-1 - dscudiero - Cosmetic/minor change/Sync
