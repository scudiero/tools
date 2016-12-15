## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:30:31.34
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

