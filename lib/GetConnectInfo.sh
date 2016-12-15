## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:35:40.27
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

