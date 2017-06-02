#!/bin/bash
export TOOLSLIBPATH="$TOOLSPATH/lib"
export TOOLSSRCPATH="$TOOLSPATH/src"

loaderDir="$(dirname $0)"
if [[ -r $HOME/tools/loader.sh ]]; then
	loaderDir="$HOME/tools"
	[[ -d "$loaderDir/lib" ]] && export TOOLSLIBPATH="$loaderDir/lib:$TOOLSLIBPATH"
	[[ -d "$loaderDir/src" ]] && export TOOLSSRCPATH="$loaderDir/src:$TOOLSSRCPATH"
fi

"$loaderDir/loader.sh" $(basename $0) $*
exit

#===================================================================================================
## Check-in log
#===================================================================================================

## 06-02-2017 @ 14.53.07 - dscudiero - General syncing of dev to prod
