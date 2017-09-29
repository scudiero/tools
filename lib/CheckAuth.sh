#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.22" # -- dscudiero -- Fri 09/29/2017 @ 13:30:25.19
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
	local sqlStmt author scriptUsers
	local scriptName=${1-$myName}

	sqlStmt="select author,restrictToUsers,restrictToGroups from $scriptsTable where name=\"$scriptName\""
	RunSql2 $sqlStmt
	[[ ${#resultSet[@]} -eq 0 ]] && echo true && return 0
	local author="$(cut -f1 -d'|' <<< ${resultSet[0]})"
	local scriptUsers="$(cut -f2 -d'|' <<< ${resultSet[0]})" ; [[ $scriptUsers == 'NULL' ]] && unset scriptUsers
	local scriptGroups="$(cut -f3 -d'|' <<< ${resultSet[0]})" ; [[ $scriptGroups == 'NULL' ]] && unset scriptGroups

	[[ $author == $userName ]] && echo true && return 0
	[[ -z ${scriptUsers}${scriptGroups} ]] && echo true && return

	if [[ -n $scriptUsers ]]; then
		scriptUsers="$(tr ' ' ',' <<< "$scriptUsers")"
		[[ $(Contains ",$scriptUsers," ",$userName,") == true ]] && echo true && return 0
	fi

	if [[ -n $scriptGroups ]]; then
		scriptGroups="\"$(sed 's/,/","/g' <<< "$scriptGroups")\""
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
## 05-10-2017 @ 09.23.21 - ("2.0.14")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 11.02.38 - ("2.0.15")  - dscudiero - Add debug stuff
## 05-19-2017 @ 11.06.08 - ("2.0.16")  - dscudiero - send debug stuff to stdout
## 05-19-2017 @ 11.12.37 - ("2.0.18")  - dscudiero - General syncing of dev to prod
## 05-19-2017 @ 11.14.50 - ("2.0.20")  - dscudiero - remove debug stuff
## 09-29-2017 @ 13.30.34 - ("2.0.22")  - dscudiero - General syncing of dev to prod
