## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:42:36.87
#===================================================================================================
# Check to see if the url is valid using ping
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function IsValidURL {
	local url=$1
	local tmpFile=$(mkTmpFile $FUNCNAME)

	ProtectedCall "ping -c 1 $url > $tmpFile 2>&1"
	grepStr=$(ProtectedCall "grep 'ping: unknown host' $tmpFile")
	[[ $grepStr == '' ]] && echo true || echo false
	rm $tmpFile
	return 0
} #IsValidURL
export -f IsValidURL

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:55 CST 2017 - dscudiero - General syncing of dev to prod
