## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.5" # -- dscudiero -- 01/04/2017 @ 13:40:06.61
#===================================================================================================
#Retrieve credentials from the .pw2 file
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function GetPW {
	searchStr=$(Trim "$*")
	pwFile=$HOME/.pw2
	unset pwRec pw
	[[ -r $pwFile ]] && pwRec=$(ProtectedCall "grep "^$searchStr" $pwFile")
	[[ $pwRec != '' ]] && echo $pwRec | cut -d' ' -f  3 || echo  ''

	return 0
} #GetPW
export -f GetPW

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:53:38 CST 2017 - dscudiero - General syncing of dev to prod
