## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.9" # -- dscudiero -- 01/04/2017 @ 13:45:53.20
#===================================================================================================
# Got HERE
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Here {

	if [[ $* == '' ]]; then
		local callerInfo=($(caller))
		echo "HERE: $(basename ${callerInfo[1]}), line: ${callerInfo[0]}"
		return
	fi

	if [[ $1 == '-l' ]]; then
		shift || true
		echo HERE $* >> $HOME/stdout.txt
	else
		echo HERE $*
	fi

	return 0
} #Here

function here { Here $* ; }
export -f Here
export -f here

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:43 CST 2017 - dscudiero - General syncing of dev to prod
