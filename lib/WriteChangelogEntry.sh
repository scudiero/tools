#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.11" # -- dscudiero -- 01/24/2017 @ 12:44:18.34
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
	[[ $DOIT != '' || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local ref=$1[@]
	local logFile="$2"
	local logger=${3-$myName}
	[[ ! -f "$logFile" ]] && touch "$logFile"

	local clientDataLogFile

	## If there is a clientData folder then write out to there also
		if [[ -n $client && -d $localClientWorkFolder ]]; then
			[[ ! -d $localClientWorkFolder/$client ]] && mkdir -p $localClientWorkFolder/$client
			clientDataLogFile="$localClientWorkFolder/$client/changelog.txt"
		fi

	## Write out records
		echo -e "\n$userName\t$(date) via '$logger' version: $version" >> "$logFile"
		[[ -n $clientDataLogFile ]] && echo -e "\n$userName\t$(date) via '$logger' version: $version" >> "$clientDataLogFile"
		[[ -n $clientDataLogFile && -n $env ]] &&  echo -e '\t\n' "Environment: ${env}${tgtEnv}" >> "$clientDataLogFile"

		if [[ -n $ref ]]; then
			printf '\t%s\n' "${!ref}" >> "$logFile"
			[[ -n $clientDataLogFile ]] && printf '\t%s\n' "${!ref}" >> "$clientDataLogFile"
		fi

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
