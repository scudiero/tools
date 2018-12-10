## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.14" # -- dscudiero -- Fri 12/07/2018 @ 14:13:34
#===================================================================================================
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CallC {
	module=$1; shift
	myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
	[[ $myRhel == 'release' ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

	## Put data into the shell env pool to make it avaiable to the called pgm
	exportVars="verify client env envs srcEnv tgtEnv product products"
	for var in $exportVars; do
			[[ -n ${!var} ]] && export $var="${!var}"
	done

	## Call pgm, check local first
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
## 12-10-2018 @ 10:37:39 - 1.0.14 - dscudiero - Change the way we export data to the program to call
