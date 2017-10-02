##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.10 # -- dscudiero -- Mon 10/02/2017 @ 14:05:51.95
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import 'FindExecutable'
executeFile=$(FindExecutable 'copyEnv')
[[ -z $executeFile || ! -r $executeFile ]] && { echo; echo; Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"; }
myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
myPath="$(dirname $executeFile)"
source $executeFile -tgtEnv pvt $scriptArgs

#==================================================================================================
# Check-in Log
#==================================================================================================
## 09-29-2017 @ 15.26.27 - (1.0.2)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.30.08 - (1.0.3)     - dscudiero - Add debug stuff
## 09-29-2017 @ 15.31.55 - (1.0.4)     - dscudiero - General syncing of dev to prod
## 09-29-2017 @ 15.34.10 - (1.0.5)     - dscudiero - Switch to use FineExecutable vs Call
## 09-29-2017 @ 16.14.36 - (1.0.8)     - dscudiero - Remove debug stuff
## 10-02-2017 @ 14.07.00 - (1.0.10)    - dscudiero - Check to make sure the executeFile has a value and is readable
