## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.13" # -- dscudiero -- Thu 12/06/2018 @ 15:04:16
#===================================================================================================
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CallC {
	module=$1; shift
	myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
	[[ $myRhel == 'release' ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

	export verify="$verify"
	if [[ -x $HOME/bin/${module}-rhel${myRhel:0:1} && $USELOCAL == true ]]; then
		eval $HOME/bin/${module}-rhel${myRhel:0:1} $*
	elif [[ -x $TOOLSPATH/bin/${module}-rhel${myRhel:0:1} ]]; then
		eval $TOOLSPATH/bin/${module}-rhel${myRhel:0:1} $*
	else 
		eval ${module}-rhel${myRhel:0:1} $*
	fi
	return $?
} #CallC
export -f CallC
#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:47 CST 2017 - dscudiero - General syncing of dev to prod
## 12-03-2018 @ 11:18:26 - 1.0.4 - dscudiero - Add full path to the module
## 12-06-2018 @ 09:54:36 - 1.0.12 - dscudiero - Update to run module from local bin if found there
## 12-07-2018 @ 07:23:33 - 1.0.13 - dscudiero - Check for local bin first
