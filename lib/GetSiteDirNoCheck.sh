#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.44" # -- dscudiero -- Fri 04/07/2017 @ 14:49:13.93
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
	local client="$1"; shift || true
	[[ -z $client ]] && return 0
	local promptStr=${1:-"Do you wish to work with a 'development' or 'production' environment"}
	local checkDir envType server ans dirs dir line
	unset siteDir
	cwd=$(pwd)

	unset envType
	if [[ -z $env ]]; then
		echo
		Prompt envType "$promptStr" 'production development' 'development'; envType=$(Lower ${envType:0:1})
		[[ $envType == 'd' ]] && validEnvs="$(tr ',' ' ' <<< $courseleafDevEnvs)" || validEnvs="$(echo "$courseleafProdEnvs" | sed s/,preview,public,prior// | tr ',' ' ')"
	fi

	## Get the server and site names
		local tmpFile=$(MkTmpFile $FUNCNAME)
		[[ -f $tmpFile ]] && rm "$tmpFile"
		if [[ $envType == 'd' ]]; then
			unset dirs
			for server in $(tr ',' ' ' <<< $devServers); do
				if [[ -d /mnt/$server/web ]]; then
					cd /mnt/$server/web
					find -mindepth 1 -maxdepth 1 -type d -name $client\* -printf "$server %f\n" >> $tmpFile
				fi
			done
		else
			for server in $(tr ',' ' ' <<< $prodServers); do
				if [[ -d /mnt/$server/$client ]]; then
					cd /mnt/$server/$client
					find -mindepth 1 -maxdepth 1 -type d -printf "$server %f\n" | grep 'next\|curr\|prior' >> $tmpFile
				fi
				[[ -d "/mnt/$server/$client-test" ]] && echo "$server test" >> $tmpFile
			done
		fi
	## Build the menu and ask the user to select the site
		local numLines=$(echo $(ProtectedCall "wc -l "$tmpFile" 2>/dev/null") | cut -d' ' -f1)
		if [[ $numLines -gt 0 ]]; then
			menuItems+=("|server/share|Site Type")
			while read -r line; do menuItems+=("|$(tr ' ' '|' <<< $line)"); done < $tmpFile;
			SelectMenuNew 'menuItems' 'menuItem' "\nEnter the $(ColorK '(ordinal)') number of the site you wish to act on (or 'x' to quit) > "
			[[ $menuItem == '' ]] && Goodbye 0
			server="$(cut -d' ' -f1 <<< $menuItem)"
			if [[ ${envType:0:1} == 'd' ]]; then
				client="$(cut -d' ' -f2 <<< $menuItem)"
				[[ $(Contains "$client" "-$userName") == true ]] && env='pvt' || env='dev'
 				siteDir="/mnt/$server/web/$client"
			else
				env="$(cut -d' ' -f2 <<< $menuItem)"
				[[ $env == 'test' ]] && client="$client-test"
				siteDir="/mnt/$server/$client/$env"
			fi
		fi

	## Done
		cd "$cwd"
		if [[ ! -d $siteDir ]]; then
			unset siteDir
			if [[ $testMode == true && -n $env ]]; then
				[[ -d  $HOME/testData/$env ]] && siteDir="$HOME/testData/$env" || unset siteDir
			else
				Error "Could not resolve the site directory with the information provided"
				Prompt siteDir "Please enter the full path to the site you wish to patch" '*dir*'
			fi
		fi
		[[ ! -d $siteDir ]] && unset siteDir
		[[ -f "$tmpFile" ]] && rm "$tmpFile"
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
## Fri Jan 20 12:47:56 CST 2017 - dscudiero - Many fixes
## Wed Jan 25 09:34:13 CST 2017 - dscudiero - minor cleanup of messaging
## Wed Feb  8 10:57:04 CST 2017 - dscudiero - Fix problem getting list of development sites
## Thu Feb  9 08:06:23 CST 2017 - dscudiero - make sure we are using our own tmpFile
## Wed Feb 22 13:09:57 CST 2017 - dscudiero - If we cannot resolve the siteDir then prompt user
## Wed Feb 22 13:36:07 CST 2017 - dscudiero - Change messaging on environment prompt
## Mon Mar  6 14:39:13 CST 2017 - dscudiero - x
## Mon Mar  6 15:56:21 CST 2017 - dscudiero - Tweak parsing results from menuSelect
## 04-07-2017 @ 14.50.29 - ("1.0.44")  - dscudiero - default directory if in test mode
