#!/bin/bash
#==================================================================================================
version=1.0.6 # -- dscudiero -- 12/02/2016 @ 10:22:15.28
#==================================================================================================
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
# Pass through script for cloneEnv forcing tgtEnv to 'pvt'
#==================================================================================================

Here 1
Call 'copyEnv' 'bash:sh' $originalArgStr -tgtEnv pvt

#===================================================================================================
## Done
#===================================================================================================
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================
## Thu Jul 14 13:28:10 CDT 2016 - dscudiero - Script that calls copyEnv and force the target to be pvt
## Thu Jul 14 14:44:00 CDT 2016 - dscudiero - Re factor call to copyEnv
## Thu Jul 21 09:33:21 CDT 2016 - dscudiero - Switch to use callPgm
## Thu Jul 21 10:25:35 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jul 21 10:28:08 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Jul 21 10:48:19 CDT 2016 - dscudiero - Switch back to directly calling copyEnv
