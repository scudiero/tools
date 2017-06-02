#!/bin/bash
if [[ -r $HOME/tools/loader.sh ]]; then
	"$HOME/tools/loader.sh" $*
else
	$(dirname $0)/loader.sh $*
fi
exit## 06-02-2017 @ 14.11.58 - dscudiero - Refectored to call loader.sh
