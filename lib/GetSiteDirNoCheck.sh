#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.10" # -- dscudiero -- 01/20/2017 @ 11:09:41.96
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
	Import 'SelectMenuNew'
	local client="$1"
	[[ -z $client ]] && return 0
	#local env="$2"
	local checkDir envType server ans dirs dir line
	unset siteDir
	cwd=$(pwd)

	unset envType env
	if [[ -z $env ]]; then
		echo
		Prompt envType "Do you wish to work with $client's development or production env" 'prod dev' 'dev'; envType=$(Lower ${envType:0:1})
		[[ $envType == 'd' ]] && validEnvs="$(tr ',' ' ' <<< $courseleafDevEnvs)" || validEnvs="$(echo "$courseleafProdEnvs" | sed s/,preview,public,prior// | tr ',' ' ')"
	fi

	## Get the server and site names
		if [[ $envType == 'd' ]]; then
			unset dirs
			for server in $(tr ',' ' ' <<< $devServers); do
				cd /mnt/$server/web
				find -mindepth 1 -maxdepth 1 -type d -name $client\* -printf "$server %f\n" > $tmpFile
			done
		else
			for server in $(tr ',' ' ' <<< $prodServers); do
				if [[ -d /mnt/$server/$client ]]; then
					cd /mnt/$server/$client
					find -mindepth 1 -maxdepth 1 -type d -printf "$server %f\n" | grep 'next\|curr\|prior' > $tmpFile
				fi
				[[ -d "/mnt/$server/$client-test" ]] && echo "$server test" >> $tmpFile
			done
		fi

	## Build the menu and ask the user to select the site
		local numLines=$(echo $(ProtectedCall "wc -l "$tmpFile"") | cut -d' ' -f1)
		if [[ $numLines -gt 0 ]]; then
			menuItems+=("|server/share| Site Type")
			while read -r line; do menuItems+=("|$(tr ' ' '|' <<< $line)"); done < $tmpFile;
			SelectMenuNew 'menuItems' 'menuItem' "\nEnter the $(ColorK '(ordinal)') number of the site you wish to act on (or 'x' to quit) > "
			[[ $menuItem == '' ]] && Goodbye 0
			server="$(cut -d'|' -f1 <<< $menuItem)"
			if [[ ${envType:0:1} == 'd' ]]; then
				env='dev'
				client="$(cut -d'|' -f2 <<< $menuItem)"
 				siteDir="/mnt/$server/web/$client"
			else
				env="$(cut -d'|' -f2 <<< $menuItem)"
				[[ $env == 'test' ]] && client="$client-test"
				siteDir="/mnt/$server/$client/$env"
			fi
		fi

	## Done
		cd "$cwd"
		[[ ! -d $siteDir ]] && unset siteDir
		return 0
}
export -f GetSiteDirNoCheck

#===================================================================================================
## Check-in log
#===================================================================================================
## Wed Jan  4 13:54:41 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 07:58:49 CST 2017 - dscudiero - Refactored to correctly write data out to the appropriate file
## Wed Jan 18 13:01:07 CST 2017 - dscudiero - Completely refactred
## Fri Jan 20 10:17:01 CST 2017 - dscudiero - Fix message wording to make in generic
## Fri Jan 20 11:10:04 CST 2017 - dscudiero - make sure we set the env variable for dev sites
