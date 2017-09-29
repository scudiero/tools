##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.2 # -- dscudiero -- Fri 09/29/2017 @ 15:26:07.42
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import 'FindExecutable'
[[ -z $executeFile ]] && executeFile=$(FindExecutable 'copyEnv')
source $executeFile -tgtEnv pvt $scriptArgs
## 09-29-2017 @ 15.26.27 - (1.0.2)     - dscudiero - General syncing of dev to prod
