#!/bin/bash
## Load boot data
	if [[ -r $(dirname $0)/bootData ]]; then
		source "$(dirname $0)/bootData"
	else
		[[ -z $TOOLSPATH ]] && TOOLSPATH="/steamboat/leepfrog/docs/tools"
		[[ ! -d $TOOLSPATH ]] && echo -e "\n*Error* -- $myName: Global variable 'TOOLSPATH' is set but is not a directory, cannot continue\n" && exit -1
		[[ ! -r $TOOLSPATH/bootData ]] && echo -e "\n*Error* -- $myName: Global variable 'TOOLSPATH' is set but you cannot access the boot record, cannot continue\n" && exit -1
		source "$TOOLSPATH/bootData"
	fi

	[[ -n $TOOLSWAREHOUSEDB ]] && warehouseDb="$TOOLSWAREHOUSEDB"
	export TOOLSWAREHOUSEDB="$warehouseDb"

## Set global search variables
	export TOOLSLIBPATH="$TOOLSPATH/lib"
	export TOOLSSRCPATH="$TOOLSPATH/src"

## Find the loader
	loaderDir="$TOOLSPATH"
	if [[ -r $HOME/tools/loader.sh ]]; then
		loaderDir="$HOME/tools"
		[[ -d "$loaderDir/lib" ]] && export TOOLSLIBPATH="$loaderDir/lib:$TOOLSLIBPATH"
		[[ -d "$loaderDir/src" ]] && export TOOLSSRCPATH="$loaderDir/src:$TOOLSSRCPATH"
	fi
	export LOADER="$loaderDir/loader.sh"

## call script loader
	if [[ $1 == '--viaCron' ]]; then
		echo -e "\t-- $hostName - sourcing \"$loaderDir/loader.sh\" $(basename $0) --batchMode $*" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
		source "$loaderDir/loader.sh" $(basename $0) --batchMode $*
		echo -e "\t\t-- $hostName - back from loader" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
		return 0
	else
		"$loaderDir/loader.sh" $(basename $0) $*
	fi

exit

#===================================================================================================
## Check-in log
#===================================================================================================
## 06-02-2017 @ 14.53.07 - dscudiero - General syncing of dev to prod
## 06-02-2017 @ 15.03.26 - dscudiero - Move boot loader to here
## 06-02-2017 @ 15.05.38 - dscudiero - Add TOOLSWAREHOUSEDB
## 06-05-2017 @ 13.47.22 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 08.49.22 - dscudiero - If called from cron then source the loader, otherwise call the loader
## 06-08-2017 @ 09.06.36 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 09.07.38 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 10.03.49 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 10.51.25 - dscudiero - add debug statements
## 06-08-2017 @ 11.38.51 - dscudiero - General syncing of dev to prod
## 06-08-2017 @ 12.21.24 - dscudiero - add debug
