#!/bin/bash
echo "\$* = '$*'"
if [[ -r $HOME/tools/loader.sh ]]; then
	"$HOME/tools/loader.sh" $*
else
	$(dirname $0)/loader.sh $*
fi
exit

#===================================================================================================
## Check-in log
#===================================================================================================
## 06-02-2017 @ 14.11.58 - dscudiero - Refectored to call loader.sh
## 06-02-2017 @ 14.14.06 - dscudiero - General syncing of dev to prod
## 06-02-2017 @ 14.23.14 - dscudiero - add debug
