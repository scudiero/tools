#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.38" # -- dscudiero -- Wed 05/16/2018 @ 14:20:08.61
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
	Import "ParseCourseleafFile"
	local ref=$1[@]
	[[ -z $ref || -n $DOIT || $listOnly == true || $informationOnlyMode == true ]] && return 0
	local logFile="$2"
	local logger=${3-$myName}
	[[ ! -f "$logFile" ]] && touch "$logFile"

	local clientDataLogFile clientSummaryLogFile
	local usersClientLogFile="/dev/null"
	local usersActivityLog="/dev/null"

	local data=$(ParseCourseleafFile "$logFile")
	local client=$(cut -d' ' -f1 <<< "$data")
	local env=$(cut -d' ' -f2 <<< "$data")

#	[[ $env == 'pvt' || $env == 'dev' ]] && return 0
	[[ $env == 'test' ]] && client=${client%-*}

	## If there is a clientData folder then write out to there also
		if [[ -n $localClientWorkFolder && -d $localClientWorkFolder ]]; then
			[[ -n $client && ! -d "$localClientWorkFolder/$client" ]] && mkdir -p $localClientWorkFolder/$client
			usersClientLogFile="$localClientWorkFolder/$client/changelog.txt"
			usersActivityLog="$localClientWorkFolder/activityLog.txt"
		fi

	## Write out records
		echo -e "\n$userName\t$(date) via '$logger' version: $version" | tee -a "$logFile" | tee -a "$usersActivityLog" >> "$usersClientLogFile"
		echo -e "\tClient: $client, Environment: $env" | tee -a "$usersActivityLog" >> "$usersClientLogFile"
		printf '\t%s\n' "${!ref}" | tee -a "$logFile" | tee -a "$usersActivityLog" >> "$usersClientLogFile"

	## Check if the user has a local logit script in $HOME/bin, if found the call it.
		if [[ -x $HOME/bin/logit ]]; then
			logText=$(sed "s_'_\\\'_"g <<< "$logger: ${!ref[0]}")
			logText=$(sed 's_\"_\\\"_'g <<< "$logText")
			$HOME/bin/logit -cl "${client:--}" -e "${env:--}" "$logText"
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
## 05-09-2017 @ 11.55.51 - ("2.0.12")  - dscudiero - Refactored how logging is done, added an user activity log file
## 05-15-2017 @ 14.24.30 - ("2.0.14")  - dscudiero - log client and environment into the activity log
## 05-24-2017 @ 13.30.23 - ("2.0.15")  - dscudiero - Strip off the -test for test environments
## 09-21-2017 @ 09.33.33 - ("2.0.30")  - dscudiero - Add call to users local logit script if it exists
## 09-21-2017 @ 11.34.51 - ("2.0.31")  - dscudiero - Change the way logit is called
## 09-21-2017 @ 12.41.05 - ("2.0.32")  - dscudiero - change the if exists check for logit to if executable
## 09-25-2017 @ 16.01.28 - ("2.0.33")  - dscudiero - add debug statement
## 10-31-2017 @ 14.41.54 - ("2.0.34")  - dscudiero - Remove debug stuff
## 11-01-2017 @ 10.27.11 - ("2.0.35")  - dscudiero - Do not write out log entries for pvt or dev sits
## 05-16-2018 @ 14:21:01 - 2.0.38 - dscudiero - Fix call to local logit sript
