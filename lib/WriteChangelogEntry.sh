#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.12" # -- dscudiero -- Tue 05/09/2017 @ 11:55:14.69
#===================================================================================================
# Write a 'standard' format courseleaf changelog.txt
# args: "logFileName" ${lineArray[@]}
# Also writes out to the changelog file in the clientData folder if found
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#===================================================================================================
# Write a 'standard' format courseleaf changelog.txt
# args: "logFileName" ${lineArray[@]}
#===================================================================================================
function WriteChangelogEntry {
	local ref=$1[@]
	[[ -z $ref || -n $DOIT || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local logFile="$2"
	local logger=${3-$myName}
	[[ ! -f "$logFile" ]] && touch "$logFile"

	local clientDataLogFile clientSummaryLogFile
	local usersClientLogFile="/dev/null"
	local usersActivityLog="/dev/null"

	## If there is a clientData folder then write out to there also
		if [[ -n $localClientWorkFolder && -d $localClientWorkFolder ]]; then
			[[ -n $client && ! -d "$localClientWorkFolder/$client" ]] && mkdir -p $localClientWorkFolder/$client
			usersClientLogFile="$localClientWorkFolder/$client/changelog.txt"
			usersActivityLog="$localClientWorkFolder/activityLog.txt"
		fi

	## Write out records
		echo -e "\n$userName\t$(date) via '$logger' version: $version" | tee -a "$logFile" | tee -a "$usersActivityLog" >> "$usersClientLogFile"
		[[ -n $env ]] && echo -e "\tEnvironment: $env" | tee -a "$usersActivityLog" >> "$usersClientLogFile"
		printf '\t%s\n' "${!ref}" | tee -a "$logFile" | tee -a "$usersActivityLog" >> "$usersClientLogFile"

	return 0
}
export -f WriteChangelogEntry

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:54:41 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 07:58:49 CST 2017 - dscudiero - Refactored to correctly write data out to the appropriate file
## Thu Jan 19 12:49:07 CST 2017 - dscudiero - x
## Tue Jan 24 12:48:10 CST 2017 - dscudiero - Fix errant '%' in the output
## 05-09-2017 @ 11.55.51 - ("2.0.12")  - dscudiero - Refactored how logging is done, added an user activity log file
