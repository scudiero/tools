#!/bin/bash
loaderDir="$(dirname $0)"
[[ -r $HOME/tools/loader.sh ]] && loaderDir="$HOME/tools/" || loaderDir="$(dirname $0)"
"$loaderDir/loader.sh" $(basename $0) $*
exit

#===================================================================================================
## Check-in log
#===================================================================================================
## 06-02-2017 @ 14.11.58 - dscudiero - Refectored to call loader.sh
## 06-02-2017 @ 14.14.06 - dscudiero - General syncing of dev to prod
## 06-02-2017 @ 14.23.14 - dscudiero - add debug
## 06-02-2017 @ 14.24.03 - dscudiero - General syncing of dev to prod
## 06-02-2017 @ 14.26.56 - dscudiero - General syncing of dev to prod
