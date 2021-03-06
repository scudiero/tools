## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.40" # -- dscudiero -- Mon 12/17/2018 @ 07:51:37
#===================================================================================================
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CallC {
	local module=$1; shift
	local myRhel=$(cat /etc/redhat-release | cut -d" " -f3)
	[[ $myRhel == 'release' ]] && myRhel=$(cat /etc/redhat-release | cut -d" " -f4)

	## Call pgm, check local first
	# local previousTrapERR=$(trap -p ERR | cut -d ' ' -f3-); trap - ERR
	export verboseLevel=$verboseLevel
	if [[ -x $HOME/bin/${module}-rhel${myRhel:0:1} && $USELOCAL == true ]]; then
		eval $HOME/bin/${module}-rhel${myRhel:0:1} $*
	elif [[ -x $TOOLSPATH/bin/${module}-rhel${myRhel:0:1} ]]; then
		eval $TOOLSPATH/bin/${module}-rhel${myRhel:0:1} $*
	else 
		eval ${module}-rhel${myRhel:0:1} $*
	fi
	rc=$?
	# [[ -n $previousTrapERR ]] && eval "trap $previousTrapERR"
	return $rc
	
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
## 12-11-2018 @ 08:49:56 - 1.0.38 - dscudiero - Add local tp variable declaraions, turn off error trapping
## 12-11-2018 @ 10:22:17 - 1.0.39 - dscudiero - Comment out error trapping
## 12-17-2018 @ 07:51:57 - 1.0.40 - dscudiero - Add exporting of verboseLevel so it is avaiable to the c program
## 03-13-2019 @ 15:07:29 - 1.0.40 - dscudiero - 
