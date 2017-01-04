## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:38:06.66
#===================================================================================================
# find out if a string contains another substring
# contains(string, substring)
# Returns false if the specified string does not contain the specified substring,
# otherwise returns true.
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Contains {
	local string="$1"
	local substring="$2"
	local testStr=${string#*$substring}

	[[ "$testStr" != "$string" ]] && echo true || echo false
	return 0
} #Contains
export -f Contains

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:08 CST 2017 - dscudiero - General syncing of dev to prod
