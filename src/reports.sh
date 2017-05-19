##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.9 # -- dscudiero -- Fri 05/19/2017 @ 14:27:46.15
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Call scriptsAndReports 'reports' $*

#==================================================================================================
# Check-in Log
#==================================================================================================
## 05-12-2017 @ 13.42.46 - (1.0.1)     - dscudiero - General syncing of dev to prod
## 05-16-2017 @ 06.45.47 - (1.0.2)     - dscudiero - If the first token in the argument list is 'cronjob.sh' then strip it off
## 05-18-2017 @ 06.58.15 - (1.0.2)     - dscudiero - add debug messages
## 05-19-2017 @ 07.26.31 - (1.0.4)     - dscudiero - remove debug stuff
## 05-19-2017 @ 14.22.32 - (1.0.8)     - dscudiero - Change call name to an absolute 'reports'
## 05-19-2017 @ 14.28.07 - (1.0.9)     - dscudiero - Changed to use absolute script name
