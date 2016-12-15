## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.4" # -- dscudiero -- 11/07/2016 @ 14:36:31.38
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

