##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.8 # -- dscudiero -- Fri 09/29/2017 @ 16:14:02.05
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import 'FindExecutable'
executeFile=$(FindExecutable 'copyEnv')
myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
myPath="$(dirname $executeFile)"
source $executeFile -tgtEnv pvt $scriptArgs
## 09-29-2017 @ 15.26.27 - (1.0.2)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.30.08 - (1.0.3)     - dscudiero - Add debug stuff
## 09-29-2017 @ 15.31.55 - (1.0.4)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.34.10 - (1.0.5)     - dscudiero - Switch to use FineExecutable vs Call
## 09-29-2017 @ 16.14.36 - (1.0.8)     - dscudiero - Remove debug stuff
