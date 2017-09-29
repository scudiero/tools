##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.5 # -- dscudiero -- Fri 09/29/2017 @ 15:33:49.38
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import 'FindExecutable'
executeFile=$(FindExecutable 'copyEnv')
source $executeFile -tgtEnv pvt $scriptArgs
## 09-29-2017 @ 15.26.27 - (1.0.2)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.30.08 - (1.0.3)     - dscudiero - Add debug stuff
## 09-29-2017 @ 15.31.55 - (1.0.4)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.34.10 - (1.0.5)     - dscudiero - Switch to use FineExecutable vs Call
