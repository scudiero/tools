##  #!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.54" # -- dscudiero -- Wed 12/06/2017 @ 10:01:31.58
#===================================================================================================
# Set Directories based on the current hostName name and school name
# Sets globals: devDir, nextDir, previewDir, publicDir, upgradeDir
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function SetSiteDirs {
	[[ -z $client ]] && Terminate "SetSiteDirs: No value for client"
	#Import "$standardInteractiveIncludes $myIncludes"

	local mode server env envDirName found foundAll checkEnv
	mode="$1"; shift || true; [[ $mode == 'set' ]] && mode='setDefault'
	[[ $mode == 'check' ]] && checkEnv="$1"

	## If setDefault mode then clear out any existing values
		[[ $mode == 'setDefault' ]] && { for env in ${courseleafDevEnvs//,/ } ${courseleafProdEnvs//,/ }; do unset ${env}Dir; done; }
	## Find dev directories
		foundAll=true
		dump -3 -n devServers courseleafDevEnvs
		for server in ${devServers//,/ }; do
			dump -3 -t server
			[[ ! -d "/mnt/$server/web/$client" && ! -d "/mnt/$server/web/$client-$userName" ]] && continue
			for env in ${courseleafDevEnvs//,/ }; do
				dump -3 -t -t env
				envDirName="${env}Dir"
				if [[ -z ${!envDirName} ]]; then
 					[[ $env == 'pvt' ]] && eval $envDirName="/mnt/$server/web/$client-$userName" || eval $envDirName="/mnt/$server/web/$client"
				fi
				[[ $mode != 'setDefault'  && ! -d ${!envDirName} ]] && unset $envDirName && foundAll=false
			done
			[[ $foundAll == true ]] && break
		done
		#dump server pvtDir devDir -p

	## Find production directories
		dump -3 -n prodServers courseleafProdEnvs
		for server in ${prodServers//,/ }; do
			dump -3 -t server
			[[ ! -d "/mnt/$server/$client-test" && ! -d "/mnt/$server/$client" ]] && continue
			for env in ${courseleafProdEnvs//,/ }; do
				dump -3 -t -t env
				envDirName="${env}Dir"
				if [[ -z ${!envDirName} ]]; then
 					[[ $env == 'test' && -z ${!envDirName} ]] && eval $envDirName="/mnt/$server/$client-$env/$env" || eval $envDirName="/mnt/$server/$client/$env"
				fi
				[[ $mode != 'setDefault'  && ! -d ${!envDirName} ]] && unset $envDirName && foundAll=false
			done
			[[ $foundAll == true ]] && break
		done
		#dump server testDir currDir previewDir publicDir priorDir -p

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
## 09-28-2017 @ 07.39.47 - ("2.0.26")  - dscudiero - fix bug in setting product dirs
## 11-01-2017 @ 15.21.01 - ("2.0.40")  - dscudiero - Simplify logic
## 11-01-2017 @ 15.26.37 - ("2.0.41")  - dscudiero - Fix a problem clearing out the directori variables
## 11-02-2017 @ 10.52.52 - ("2.0.43")  - dscudiero - Tweak how we check for pvt and test sites
## 11-02-2017 @ 11.22.32 - ("2.0.44")  - dscudiero - Cosmetic/minor change
## 11-02-2017 @ 11.40.20 - ("2.0.52")  - dscudiero - Fix problem setting dev and pvt dirs
## 12-06-2017 @ 09.05.30 - ("2.0.53")  - dscudiero - Add debug statements
## 12-06-2017 @ 10.01.51 - ("2.0.54")  - dscudiero - Switch debug statements to level 3
