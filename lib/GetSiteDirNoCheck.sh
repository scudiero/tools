#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.1" # -- dscudiero -- 01/12/2017 @  9:51:34.79
#===================================================================================================
# Resolve a clients siteDir without using the database
# Sets global variable: siteDir
#===================================================================================================
# CopyrighFt 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
#===================================================================================================
# Write a 'standard' format courseleaf changelog.txt
# args: "logFileName" ${lineArray[@]}
#===================================================================================================
function GetSiteDirNoCheck {
	local client="$1"
	[[ -z $client ]] && return 0
	local env="$2"
	local checkDir envType server
	unset siteDir
	while [[ -z $siteDir ]]; do
		unset ans
		Prompt ans "Does $client's site directory use standard naming conventions" 'Yes No' 'Yes' ; ans=$(Lower ${ans:0:1})
		if [[ $ans == 'y' ]]; then
			unset envType env
			if [[ -z $env ]]; then
				echo
				Prompt envType "Do you wish to patch $client's development or production env" 'prod dev' 'prod'; envType=$(Lower ${envType:0:1})
				[[ $envType == 'd' ]] && validEnvs="$(tr ',' ' ' <<< $courseleafDevEnvs)" || validEnvs="$(echo "$courseleafProdEnvs" | sed s/,preview,public,prior// | tr ',' ' ')"
			fi
			Prompt env "What environment do you wish to patch" "$validEnvs"
			if [[ $env == 'dev' || $env == 'pvt' ]]; then
				for server in $(tr ',' ' ' <<< $devServers); do
					checkDir="/mnt/$server/web/$client/$env"
					[[ $env == 'pvt' ]] && checkDir="/mnt/$server/web/$client-$userName/$env"
					[[ -d $checkDir ]] && break
				done
			else
				for server in $(tr ',' ' ' <<< $prodServers); do
					checkDir="/mnt/$server/$client/$env"
					[[ $env == 'test' ]] && checkDir="/mnt/$server/$client-test/$env"
					[[ -d $checkDir ]] && break
				done
			fi
			[[ -d $checkDir ]] && siteDir="$checkDir" && break
			unset envType envType siteDir
			Error "Could not locate '$checkDir', please try again"
		else
			Prompt siteDir 'Please specify full file name to the target site root directory' '*dir*'
		fi
	done
	return 0
}
export -f GetSiteDirNoCheck

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:54:41 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 07:58:49 CST 2017 - dscudiero - Refactored to correctly write data out to the appropriate file
