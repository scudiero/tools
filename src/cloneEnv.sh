##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.3 # -- dscudiero -- Fri 09/29/2017 @ 15:29:28.23
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
[[ $userName == 'dscudiero' ]] && Here CloneEnv 0
Import 'FindExecutable'
[[ -z $executeFile ]] && executeFile=$(FindExecutable 'copyEnv')
[[ $userName == 'dscudiero' ]] && echo && echo "HERE 2" && echo "executeFile = '$executeFile'"

source $executeFile -tgtEnv pvt $scriptArgs
## 09-29-2017 @ 15.26.27 - (1.0.2)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.30.08 - (1.0.3)     - dscudiero - Add debug stuff
