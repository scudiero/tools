##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.7 # -- dscudiero -- Mon 10/02/2017 @ 13:15:22.69
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import 'FindExecutable'
executeFile=$(FindExecutable 'scriptsAndReports')
myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
myPath="$(dirname $executeFile)"
source $executeFile 'scripts' $*
## 05-19-2017 @ 14.22.51 - (1.0.2)     - dscudiero - Change the call name to an absolute 'scripts'
## 05-19-2017 @ 14.26.50 - (1.0.3)     - dscudiero - Change call to use absolute name
## 05-31-2017 @ 07.58.02 - (1.0.4)     - dscudiero - General syncing of dev to prod
## 09-13-2017 @ 08.33.06 - (1.0.5)     - dscudiero - Import Call before usage
## 10-02-2017 @ 13.14.25 - (1.0.6)     - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.15.32 - (1.0.7)     - dscudiero - General syncing of dev to prod
