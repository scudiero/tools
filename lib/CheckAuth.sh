#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.38" # -- dscudiero -- Fri 11/03/2017 @ 16:32:08.48
#===================================================================================================
# Check to see if the logged user can run this script
# Returns true if user is authorized, otherwise it returns a message
# Always returns true if the script is not registerd in the scripts database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CheckAuth {
	Import 'RunSql2'
	local sqlStmt author restrictGroups
	local scriptName=${1-$myName}
	unset author restrictGroups

	[[ -z $UsersAuthGroups && -r "$TOOLSPATH/auth/$userName" ]] && UsersAuthGroups=$(cat "$TOOLSPATH/auth/$userName") || UsersAuthGroups='none'
	## Get the retricted information for the script
		whereClauseUser="and (restrictToUsers like \"%$userName%\" or restrictToUsers is null)"
		sqlStmt="select author,restrictToGroups from $scriptsTable where name=\"$scriptName\" $whereClauseUser"
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && echo true && return 0
		result="${resultSet[0]}"
		author="${result%%|*}"; result="${result#*|}";
		[[ $author == $userName ]] && { echo true; return 0; }
		restrictGroups="$result"

	## If there is restrictToGroups data then check
		found=false
		if [[ -n $restrictGroups && $restrictGroups != 'NULL' ]]; then
			for group in ${UsersAuthGroups//,/ }; do
				[[ $(Contains ",$restrictGroups," ",$group,") == true ]] && { echo true; return 0; }
			done
		else
			echo true
			return 0
		fi

	## User does not have access
	echo "Sorry, you do not have permissions to run '$scriptName', the script is restricted to groups: '${restrictGroups//,/, }'.  FYI, you are in these groups: '${UsersAuthGroups//,/, }'"
	return 0

} #CheckAuth
export -f CheckAuth
#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:56 CST 2017 - dscudiero - General syncing of dev to prod
## 05-09-2017 @ 13.57.12 - ("2.0.8")   - dscudiero - Refactored to improve performance
## 05-10-2017 @ 09.22.33 - ("2.0.13")  - dscudiero - Fix error not setting myname propery
## 05-10-2017 @ 09.23.21 - ("2.0.14")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 11.02.38 - ("2.0.15")  - dscudiero - Add debug stuff
## 05-19-2017 @ 11.06.08 - ("2.0.16")  - dscudiero - send debug stuff to stdout
## 05-19-2017 @ 11.12.37 - ("2.0.18")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 11.14.50 - ("2.0.20")  - dscudiero - remove debug stuff
## 09-29-2017 @ 13.30.34 - ("2.0.22")  - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.36.14 - ("2.0.23")  - dscudiero - Remove all the UserAuthGroups stuff, moved to loader
## 11-06-2017 @ 07.22.41 - ("2.0.38")  - dscudiero - Switch to using the auth files
