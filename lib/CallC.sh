## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.4" # -- dscudiero -- Mon 12/03/2018 @ 11:17:31
#===================================================================================================
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CallC {
	module=$1; shift
	myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
	[[ $myRhel == 'release' ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

	eval $TOOLSPATH/bin/${module}-rhel${myRhel:0:1} $*
	return $?
} #CallC
export -f CallC
#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:47 CST 2017 - dscudiero - General syncing of dev to prod
## 12-03-2018 @ 11:18:26 - 1.0.4 - dscudiero - Add full path to the module
