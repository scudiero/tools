#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- 01/04/2017 @ 13:51:23.26
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

	## If there is a clientData folder then writout there also
		if [[ -d $localClientWorkFolder ]]; then
			[[ ! -d $localClientWorkFolder/$client ]] && mkdir -p $localClientWorkFolder/$client
			clientDataLogFile="$localClientWorkFolder/$client/changelog.txt"
		else
			clientDataLogFile="/dev/null"
		fi

	## Write out records
		printf "\n$userName\t$(date) via '$logger' version: $version\n" >> "$logFile"
		printf "\n$userName\t$(date) via '$logger' version: $version\n" >> "$clientDataLogFile"

		printf '\t%s\n' "Environment: ${env}${tgtEnv}" >> "$clientDataLogFile"

		if [[ $ref != '' ]]; then
			printf '\t%s\n' "${!ref}" >> "$logFile" >> "$logFile"
			printf '\t%s\n' "${!ref}" >> "$logFile" >> "$clientDataLogFile"
		fi

	return 0
}
export -f WriteChangelogEntry

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:54:41 CST 2017 - dscudiero - General syncing of dev to prod
