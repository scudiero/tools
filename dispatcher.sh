#!/bin/bash

## Make sure we have a TOOLSPATH and it is valid
	[[ -z $TOOLSPATH ]] && TOOLSPATH="/steamboat/leepfrog/docs/tools"
	[[ ! -d $TOOLSPATH ]] && echo -e "\n*Error* -- $myName: Global variable 'TOOLSPATH' is set but is not a directory, cannot continue\n" && exit -1
	[[ ! -r $TOOLSPATH/bootData ]] && echo -e "\n*Error* -- $myName: Global variable 'TOOLSPATH' is set but you cannot access the boot record, cannot continue\n" && exit -1
	export TOOLSPATH="$TOOLSPATH"

## Load boot data
	[[ -r $(dirname $0)/bootData ]] && source "$(dirname $0)/bootData" || source "$TOOLSPATH/bootData"

## Set global variables
	export TOOLSWAREHOUSEDB="$warehouseDb"
	export TOOLSLIBPATH="$TOOLSPATH/lib"
	export TOOLSSRCPATH="$TOOLSPATH/src"
	export SCRIPTINCLUDES

	[[ -n $TOOLSWAREHOUSEDBNAME ]] && warehouseDb="$TOOLSWAREHOUSEDBNAME"
	export TOOLSWAREHOUSEDBNAME="$warehouseDbName"

	[[ -n $TOOLSWAREHOUSEDBHOST ]] && warehouseDbHost="$TOOLSWAREHOUSEDBHOST"
	export TOOLSWAREHOUSEDBHOST="$warehouseDbHost"

	export TOOLSDEFAULTSPATH="$TOOLSPATH/shadows/toolsDefaults"

## Find the loader
	loaderDir="$TOOLSPATH"
	if [[ $1 == '--useLocal' && -r $HOME/tools/loader.sh ]]; then
		loaderDir="$HOME/tools"
		[[ -d "$loaderDir/lib" ]] && export TOOLSLIBPATH="$loaderDir/lib:$TOOLSLIBPATH"
		[[ -d "$loaderDir/src" ]] && export TOOLSSRCPATH="$loaderDir/src:$TOOLSSRCPATH"
	fi
	export LOADER="$loaderDir/loader.sh"

## call script loader
	if [[ $1 == '--viaCron' ]]; then
		#echo -e "\t-- $hostName - sourcing \"$loaderDir/loader.sh\" $(basename $0) --batchMode $*" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
		source "$loaderDir/loader.sh" $(basename $0) --batchMode $*
		#echo -e "\t\t-- $hostName - back from loader" >> $TOOLSPATH/Logs/cronJobs/cronJobs.log
		return 0
	else
		source "$loaderDir/loader.sh" $(basename $0) $*
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
## 06-12-2017 @ 07.26.00 - dscudiero - Make sure we have TOOLSPATH set
## 06-12-2017 @ 11.01.10 - dscudiero - add debug
## 06-12-2017 @ 11.08.50 - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.09.48 - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.18.41 - dscudiero - export the value of toolspath
## 06-12-2017 @ 11.24.02 - dscudiero - General syncing of dev to prod
## 06-12-2017 @ 11.24.54 - dscudiero - remove debug statements
## 06-14-2017 @ 07.49.36 - dscudiero - Add debug messages
## 06-14-2017 @ 08.08.05 - dscudiero - Remove debug statements
## 06-26-2017 @ 07.50.30 - dscudiero - Add warhousedbHost, renamed warehousedb to warehousedbname
## 06-26-2017 @ 10.19.37 - dscudiero - set TOOLSWAREHOUSEDB
## 09-07-2017 @ 07.15.08 - dscudiero - add debug statement
## 09-07-2017 @ 08.11.55 - dscudiero - Add debug for me
## 09-07-2017 @ 08.52.42 - dscudiero - add setting of SCRIPTINCLUDES
## 09-08-2017 @ 16.28.53 - dscudiero - Check for the --useLocal directive as the first token before using local loader
## 09-28-2017 @ 09.02.58 - dscudiero - Add setting of TOOLSDEFAULTSPATH
## 10-16-2017 @ 13.56.18 - dscudiero - Comment out loader log statements
