##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.17 # -- dscudiero -- Mon 10/23/2017 @  8:40:34.40
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import 'FindExecutable'
executeFile=$(FindExecutable 'scriptsAndReports')
[[ -z $executeFile || ! -r $executeFile ]] && { echo; echo; Terminate "$myName.sh.$LINENO: Could not resolve the script source file:\n\t$executeFile"; }
myName="$(cut -d'.' -f1 <<< $(basename $executeFile))"
myPath="$(dirname $executeFile)"
source $executeFile reports $*

#==================================================================================================
# Check-in Log
#==================================================================================================
## 05-12-2017 @ 13.42.46 - (1.0.1)     - dscudiero - General syncing of dev to prod
## 05-16-2017 @ 06.45.47 - (1.0.2)     - dscudiero - If the first token in the argument list is 'cronjob.sh' then strip it off
## 05-18-2017 @ 06.58.15 - (1.0.2)     - dscudiero - add debug messages
## 05-19-2017 @ 07.26.31 - (1.0.4)     - dscudiero - remove debug stuff
## 05-19-2017 @ 14.22.32 - (1.0.8)     - dscudiero - Change call name to an absolute 'reports'
## 05-19-2017 @ 14.28.07 - (1.0.9)     - dscudiero - Changed to use absolute script name
## 05-24-2017 @ 08.08.44 - (1.0.12)    - dscudiero - Add commented debug statement
## 05-31-2017 @ 07.57.33 - (1.0.12)    - dscudiero - quote scriptAndReports
## 09-13-2017 @ 08.32.07 - (1.0.13)    - dscudiero - Import the Call procedure before use
## 10-02-2017 @ 14.07.08 - (1.0.14)    - dscudiero - Check to make sure the executeFile has a value and is readable
## 10-23-2017 @ 08.41.20 - (1.0.17)    - dscudiero - remove ddebug stuff
