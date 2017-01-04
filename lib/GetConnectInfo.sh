## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:39:17.39
#===================================================================================================
# Get connection information from the users .pw2 file
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function GetConnectInfo {
	local key="$1"
	local alternateFile="$2"

	local pwFile=$HOME/.pw2
	local pwRec
	[[ -r $pwFile ]] && pwRec=$(ProtectedCall "grep -m 1 "^$key" $pwFile")
	[[ $pwRec == '' &&  -r $alternateFile ]] && pwRec=$(ProtectedCall "grep -m 1 "^$key" $alternateFile")
	echo "$(echo $pwRec | tr -d '\011\012\015')"
	return 0
} #GetConnectInfo
export -f GetConnectInfo

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:31 CST 2017 - dscudiero - General syncing of dev to prod
