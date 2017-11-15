## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.12" # -- dscudiero -- Wed 11/15/2017 @  8:31:02.09
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

	if [[ $1 == '-s' && -n $stdout ]]; then
		shift || true
		echo HERE: $* >> $stdout
	else
		echo HERE: $*
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
## 11-15-2017 @ 08.29.15 - ("2.0.10")  - dscudiero - Added -s option to write to $stdout
## 11-15-2017 @ 08.33.18 - ("2.0.12")  - dscudiero - Cosmetic/minor change
