## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.22" # -- dscudiero -- Wed 09/27/2017 @ 10:58:47.04
#===================================================================================================
# Set Directories based on the current hostName name and school name
# Sets globals: devDir, nextDir, previewDir, publicDir, upgradeDir
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetSiteDirs {
	[[ -z $client ]] && Terminate "SetSiteDirs: No value for client"
	myIncludes="RunSql2"
	Import "$standardInteractiveIncludes $myIncludes"

	local mode="$1"; shift || true
	[[ $mode == 'check' ]] && local checkEnv="$2"
	local server env

	## Find dev directories
	for server in $(tr ',' ' ' <<< "$devServers"); do
		for env in $(tr ',' ' ' <<< "$courseleafDevEnvs"); do
			[[ $mode == 'setDefault' ]] && unset ${env}Dir
			if [[ $env == pvt ]]; then
				[[ -z $pvtDir && $mode == 'setDefault' ]] && pvtDir="/mnt/$server/web/$client-$userName"
				[[ $mode != 'setDefault' && -d "/mnt/$server/web/$client-$userName" ]] && pvtDir="/mnt/$server/web/$client-$userName"
			fi
			if [[ $env == dev ]]; then
				[[ -z $devDir && $mode == 'setDefault' ]] && devDir="/mnt/$server/web/$client"
				[[ $mode != 'setDefault' && -d "/mnt/$server/web/$client" ]] && devDir="/mnt/$server/web/$client"
			fi
		done
		[[ -n $pvtDir && -n $devDir ]] && break
	done
	#dump server pvtDir devDir devSiteDir

	## Find production directories
	unset testDir currDir previewDir publicDir priorDir
	for server in $(tr ',' ' ' <<< "$prodServers"); do
		for env in $(tr ',' ' ' <<< "$courseleafProdEnvs"); do
			[[ $mode == 'setDefault' ]] && unset ${env}Dir
			if [[ $env == test ]]; then
				[[ -z $testDir && $mode == 'setDefault' ]] && testDir="/mnt/$server/$client-$env/$env"
				[[ $mode != 'setDefault' && -d "/mnt/$server/$client-$env/$env" ]] && testDir="/mnt/$server/$client-$env/$env"
			else
				local token="${env}Dir"
				[[ -z ${!token} && $mode == 'setDefault' ]] && eval $token="/mnt/$server/$client/$env"
				[[ $mode != 'setDefault' && -d "/mnt/$server/$client/$env" ]] && eval $token="/mnt/$server/$client/$env"
			fi
		done
		[[ -n $testDir && -n $currDir && -n $previewDir && -n $publicDir && -n $priorDir ]] && break
	done
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
## 09-27-2017 @ 07.52.22 - ("2.0.21")  - dscudiero - General syncing of dev to prod
## 09-27-2017 @ 10.59.03 - ("2.0.22")  - dscudiero - Fix problem with setDefault
