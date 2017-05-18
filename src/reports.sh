##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.2 # -- dscudiero -- Tue 05/16/2017 @  6:45:13.15
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
echo "starting reports"
echo "\$* = >$*<"
[[ $1 == 'cronjob.sh' ]] && shift || true
Call scriptsAndReports $(basename $0) $*
## 05-12-2017 @ 13.42.46 - (1.0.1)     - dscudiero - General syncing of dev to prod
## 05-16-2017 @ 06.45.47 - (1.0.2)     - dscudiero - If the first token in the argument list is 'cronjob.sh' then strip it off
## 05-18-2017 @ 06.58.15 - (1.0.2)     - dscudiero - add debug messages
