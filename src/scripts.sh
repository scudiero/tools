##  #!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.5 # -- dscudiero -- Wed 09/13/2017 @  8:31:23.83
#==================================================================================================
# Quick call to scriptsAndReports
#==================================================================================================
Import "Call"
Call 'scriptsAndReports' 'scripts' $*
## 05-19-2017 @ 14.22.51 - (1.0.2)     - dscudiero - Change the call name to an absolute 'scripts'
## 05-19-2017 @ 14.26.50 - (1.0.3)     - dscudiero - Change call to use absolute name
## 05-31-2017 @ 07.58.02 - (1.0.4)     - dscudiero - General syncing of dev to prod
## 09-13-2017 @ 08.33.06 - (1.0.5)     - dscudiero - Import Call before usage
