#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.13" # -- dscudiero -- Wed 05/10/2017 @  9:21:41.53
#===================================================================================================
# Check to see if the logged user can run this script
# Returns true if user is authorized, otherwise it returns a message
# Always returns true if the script is not registerd in the scripts database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CheckAuth {
	local sqlStmt author scriptUsers
	local myName=${1-$myName}

	sqlStmt="select author,restrictToUsers,restrictToGroups from $scriptsTable where name=\"$myName\""
	RunSql2 $sqlStmt

	[[ ${#resultSet[@]} -eq 0 ]] && echo true && return 0
	local author="$(cut -f1 -d'|' <<< ${resultSet[0]})"
	[[ $author == $userName ]] && echo true && return 0

	local scriptUsers="$(cut -f2 -d'|' <<< ${resultSet[0]})"
	scriptUsers="$(tr ' ' ',' <<< "$scriptUsers")"
	if [[ $scriptUsers != 'NULL' && -n $scriptUsers ]]; then
		[[ $(Contains ",$scriptUsers," ",$userName,") == true ]] && echo true && return 0
	fi

	local scriptGroups="$(cut -f3 -d'|' <<< ${resultSet[0]})"; scriptGroups="\"$(sed 's/,/","/g' <<< "$scriptGroups")\""
	if [[ $scriptGroups != \"NULL\" && -n $scriptGroups ]]; then
		sqlStmt="select code from $authGroupsTable where members like \"%,$userName,%\" and code in ($scriptGroups)"
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -ne 0 ]] && echo true && return 0
	fi

	## User does not have access
	echo "The logged in user ($userName) does not have permissions to run this script."
	return 0

} #CheckAuth
export -f CheckAuth

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:56 CST 2017 - dscudiero - General syncing of dev to prod
## 05-09-2017 @ 13.57.12 - ("2.0.8")   - dscudiero - Refactored to improve performance
## 05-10-2017 @ 09.22.33 - ("2.0.13")  - dscudiero - Fix error not setting myname propery
