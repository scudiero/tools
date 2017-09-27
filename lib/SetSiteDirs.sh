## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.23" # -- dscudiero -- Wed 09/27/2017 @ 11:50:14.23
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

	local mode server env token checkEnv
	mode="$1"; shift || true; [[ $mode == 'set' ]] && mode='setDefault'
	[[ $mode == 'check' ]] && checkEnv="$1"

	## If setDefault mode then clear out any existing values
		if [[ $mode == 'setDefault' ]]; then
			for env in $(tr ',' ' ' <<< "$courseleafDevEnvs $courseleafProdEnvs"); do
				unset ${env}Dir
			done
		fi

	## Find dev directories
		for server in $(tr ',' ' ' <<< "$devServers"); do
			[[ ! -d "/mnt/$server/web/$client" && ! -d "/mnt/$server/web/$client-$userName" ]] && continue
			for env in $(tr ',' ' ' <<< "$courseleafDevEnvs"); do
				token="${env}Dir"
				if [[ $env == 'pvt' && -z ${!token} ]]; then
					if [[ $mode == 'setDefault' ]]; then
						pvtDir="/mnt/$server/web/$client-$userName"
					else
						[[ -d "/mnt/$server/web/$client-$userName" ]] && pvtDir="/mnt/$server/web/$client-$userName"
					fi
				fi
				if [[ $env == 'dev' && -z ${!token} ]]; then
					if [[ $mode == 'setDefault' ]]; then
						devDir="/mnt/$server/web/$client"
					else
						[[ -d "/mnt/$server/web/$client" ]] && devDir="/mnt/$server/web/$client"
					fi
				fi
			done
			[[ -n $pvtDir && -n $devDir ]] && break
		done
		#dump server pvtDir devDir devSiteDir

	## Find production directories
		unset testDir currDir previewDir publicDir priorDir
		for server in $(tr ',' ' ' <<< "$prodServers"); do
			[[ ! -d "/mnt/$server/$client-$env" && ! -d "/mnt/$server/$client" ]] && continue

			for env in $(tr ',' ' ' <<< "$courseleafProdEnvs"); do
				token="${env}Dir"
				if [[ $env == 'test' && -z ${!token} ]]; then
					if [[ $mode == 'setDefault' ]]; then
						testDir="/mnt/$server/$client-$env/$env"
					else
						[[ -d "/mnt/$server/$client-$env/$env" ]] && testDir="/mnt/$server/$client-$env/$env"
					fi
				else
					if [[ $mode == 'setDefault' ]]; then
						eval $token="/mnt/$server/$client/$env"
					else
						[[ -d "/mnt/$server/$client/$env" ]] && eval $token="/mnt/$server/$client/$env"
					fi
				fi
			done

			[[ -n $testDir && -n $currDir && -n $previewDir && -n $publicDir && -n $priorDir ]] && break
		done
		#dump server testDir currDir previewDir publicDir priorDir prodSiteDir

	## If check mode, make sure the indicated environment diretory exists
		if [[ $mode == 'check' ]]; then
			local checkDir="${checkEnv}Dir"
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
## 09-27-2017 @ 11.50.43 - ("2.0.23")  - dscudiero - tweak logic
