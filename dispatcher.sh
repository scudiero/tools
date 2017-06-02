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

## Set global search variables
	export TOOLSLIBPATH="$TOOLSPATH/lib"
	export TOOLSSRCPATH="$TOOLSPATH/src"

## Find the loader
	loaderDir="$(dirname $0)"
	if [[ -r $HOME/tools/loader.sh ]]; then
		loaderDir="$HOME/tools"
		[[ -d "$loaderDir/lib" ]] && export TOOLSLIBPATH="$loaderDir/lib:$TOOLSLIBPATH"
		[[ -d "$loaderDir/src" ]] && export TOOLSSRCPATH="$loaderDir/src:$TOOLSSRCPATH"
	fi
	export LOADER="$loaderDir/loader.sh"

## call script loader
	"$loaderDir/loader.sh" $(basename $0) $*

exit

#===================================================================================================
## Check-in log
#===================================================================================================
## 06-02-2017 @ 14.53.07 - dscudiero - General syncing of dev to prod
## 06-02-2017 @ 15.03.26 - dscudiero - Move boot loader to here
