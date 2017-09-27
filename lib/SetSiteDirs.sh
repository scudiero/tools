## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.20" # -- dscudiero -- Wed 09/27/2017 @  7:43:54.97
#===================================================================================================
# Set Directories based on the current hostName name and school name
# Sets globals: devDir, nextDir, previewDir, publicDir, upgradeDir
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetSiteDirs {
	myIncludes="RunSql2"
	Import "$standardInteractiveIncludes $myIncludes"

	local mode="${1:-setDefault}"; shift || true
	[[ $mode == 'check' ]] && local checkEnv="$2"
	[[ -z $client ]] && Terminate "SetSiteDirs: No value for client"
	local server env checkDir

	## Find dev directories
	unset pvtDir devDir
	for server in $(tr ',' ' ' <<< "$devServers"); do
		for env in $(tr ',' ' ' <<< "$courseleafDevEnvs"); do
			unset ${chkenv}Dir
			[[ $env == pvt && -d /mnt/$server/web/$client-$userName ]] && eval pvtDir="/mnt/$server/web/$client-$userName"
			[[ $env == dev && -d /mnt/$server/web/$client ]] && eval devDir="/mnt/$server/web/$client"
		done
		[[ -n $pvtDir && -n $devDir ]] && break
	done
	[[ -n $devDir ]] && devSiteDir="$devDir" || unset devSiteDir
	#dump server pvtDir devDir devSiteDir

	## Find production directories
	unset testDir currDir previewDir publicDir priorDir
	for server in $(tr ',' ' ' <<< "$prodServers"); do
		for env in $(tr ',' ' ' <<< "$courseleafProdEnvs"); do
			if [[ $env == 'test' ]]; then
				[[ -d /mnt/$server/$client-$env/$env && -z $testDir ]] && testDir="/mnt/$server/$client-$env/$env"
			else
				local token="${env}Dir"
				[[ -d /mnt/$server/$client/$env && -z ${!token} ]] && eval $token="/mnt/$server/$client/$env"
			fi
		done
		[[ -n $testDir && -n $currDir && -n $previewDir && -n $publicDir && -n $priorDir ]] && break
	done
	[[ -n $nextDir ]] && prodSiteDir=$(dirname $nextDir) || unset prodSiteDir
	#dump server testDir currDir previewDir publicDir priorDir prodSiteDir

	## If check mode, make sure the indicated environment diretory exists
	if [[ $mode == 'check' ]]; then
		local checkDir="${checkDir}Dir"
		[[ -d ${!checkDir} ]] && echo true || echo false
	fi

	return 0
} #SetSiteDirs

export -f SetSiteDirs

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:27 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan  5 14:53:53 CST 2017 - dscudiero - refactored checking for test site
## Fri Jan  6 14:39:27 CST 2017 - dscudiero - General cleanup , swithch to use -z and -n
## 09-27-2017 @ 07.51.27 - ("2.0.20")  - dscudiero - refactored
