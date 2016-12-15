#!/bin/bash
## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:41:38.60
#===================================================================================================
# Lower case a string
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function Lower {
	## Need to use printf, echo absorbs '-n'
	printf "%s" $(printf "%s" "$*" | tr '[:upper:]' '[:lower:]')
	return 0
} #Lower
export -f Lower

#===================================================================================================
# Check-in Log
#===================================================================================================

