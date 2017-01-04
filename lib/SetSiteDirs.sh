## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- 01/04/2017 @ 13:49:00.55
#===================================================================================================
# Set Directories based on the current hostName name and school name
# Sets globals: devDir, nextDir, previewDir, publicDir, upgradeDir
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function SetSiteDirs {
	local mode=$1
	if [[ $mode == 'check' ]]; then local checkEnv=$2; fi

	if [[ "$client" = "" ]]; then client=$school; fi
	if [[ "$client" = '' ]]; then printf "SetSiteDirs: No value for client/school.  Stopping\n\a"; Goodbye 1; fi

	local dir=""
	## Find dev directories
	for server in $(echo $devServers | tr ',' ' '); do
		foundClient=false
		for chkenv in $(echo $courseleafDevEnvs | tr ',' ' '); do
			unset ${chkenv}Dir
			[[ $chkenv == pvt && -d /mnt/$server/web/$client-$userName ]] && eval ${chkenv}Dir=/mnt/$server/web/$client-$userName && foundClient=true && continue
			[[ $chkenv == dev && -d /mnt/$server/web/$client ]] && eval ${chkenv}Dir=/mnt/$server/web/$client && foundClient=true && continue
		done
		[[ -d "/mnt/$server/web/$client-cim" ]] && testDir="cimDevDir=/mnt/$server/web/$client-cim"
		[[ $foundClient == true ]] && break
	done

	## Find production directories
	skelDir=$skeletonRoot/release
	for server in $(echo $prodServers | tr ',' ' '); do
		foundClient=false
		for chkenv in $(echo $courseleafProdEnvs | tr ',' ' '); do
			unset ${chkenv}Dir
			[[ -d /mnt/$server/$client/$chkenv ]] && eval ${chkenv}Dir=/mnt/$server/$client/$chkenv && foundClient=true
		done
		[[ -d "/mnt/$server/$client-test/test" ]] && testDir="/mnt/$server/$client-test/test"
		[[ $foundClient == true ]] && break
	done

	if [[ $mode = 'setDefault' ]]; then
		if [[ $nextDir == '' ]]; then
			if [[ $noCheck != true ]]; then
				## Get the share and
				sqlStmt="select share from $siteInfoTable where name=\"$client\" and env=\"next\""
				RunSql 'mysql' $sqlStmt
				if [[ ${#resultSet[@]} -gt 0 ]]; then
					nextDir="/mnt/${resultSet[0]}/$client/next"
				else
					Msg2 $T "SetSiteDirs: Mode is $mode and could not resolve the NEXT site directory"
				fi
			else
				nextDir="/mnt/$server/$client/next/"
			fi
		fi
		[[ $testDir == '' ]] && testDir=$(sed "s!/next!-test/test!" <<< $nextDir)
		[[ $currDir == '' ]] && currDir=$(sed "s/next/curr/" <<< $nextDir)
		[[ $previewDir == '' ]] && previewDir=$(sed "s/next/preview/" <<< $nextDir)
		[[ $priorDir == '' ]] && priorDir=$(sed "s/next/prior/" <<< $nextDir)
		[[ $publicDir == '' ]] &&  publicDir=$(sed "s/next/public/" <<< $nextDir)
		[[ $devDir == '' ]] && devDir="/mnt/$defaultDevServer/web/$client"
		[[ $pvtDir == '' ]] && pvtDir=$(sed "s!$client!$client-$userName!" <<< $devDir)
		devSiteDir=$devDir
		prodSiteDir=$(dirname $nextDir)
	fi

	if [[ $mode == 'check' ]]; then
		local checkDir='Dir'
		eval checkDir=\$$checkEnv$checkDir
		[[ -d $checkDir ]] && echo true || echo false
	fi

	return 0
} #SetSiteDirs
export -f SetSiteDirs

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:27 CST 2017 - dscudiero - General syncing of dev to prod
