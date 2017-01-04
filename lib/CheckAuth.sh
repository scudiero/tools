#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- 01/04/2017 @ 13:36:35.62
#===================================================================================================
# Check to see if the logged user can run this script
# Returns true if user is authorized, otherwise it returns a message
# Always returns true if the script is not registerd in the scripts database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CheckAuth {
	local sqlStmt

	## check to see if script is in the scripts table
		local sqlStmt="select count(*) from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		[[ ${resultSet[0]} -eq 0 ]] && echo true && return 0

	## check user to see if they are the author
		sqlStmt="select author from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			local author="${resultSet[0]}"
			[[ $author == $userName ]] && echo true && return 0
		fi

	## check user restrict informaton for this script
		local haveRestrictToUsers=false
		sqlStmt="select restrictToUsers from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			local scriptUsers="$(echo ${resultSet[0]} | tr ' ' ',')"
			if [[ $scriptUsers != 'NULL' && $scriptUsers != '' ]]; then
				haveRestrictToUsers=true
				[[ $(Contains ",$scriptUsers," ",$userName,") == true ]] && echo true && return 0
			fi
		fi

	## check group restrict informaton for this script
		local haveRestrictToGroups=false
		sqlStmt="select restrictToGroups from $scriptsTable where name=\"$myName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			local scriptGroups="\"$(echo ${resultSet[0]} | sed 's/,/","/g')\""
			if [[ $scriptGroups != \"NULL\" && $scriptGroups != '' ]]; then
				haveRestrictToGroups=true
				sqlStmt="select code from $authGroupsTable where members like \"%,$userName,%\" and code in ($scriptGroups)"
				RunSql 'mysql' $sqlStmt
				[[ ${#resultSet[@]} -ne 0 ]] && echo true && return 0
			fi
		fi
		[[ $haveRestrictToUsers == false && $haveRestrictToGroups == false ]] && echo true && return 0

	## User does not have access
	Msg2 "Current user ($userName) does not have permissions to run this script."
	if [[ $restrictToGroupsIsNull == false || $restrictToUsersIsNull == false ]]; then
		Msg2 "^Script $myName is restricted to:"
		[[ $haveRestrictToUsers == true ]] && Msg2 "^Users in {$scriptUsers}"
		[[ $haveRestrictToGroups == true ]] && Msg2 "^Users in auth group(s) {$scriptGroups}"
	fi
	return 0

} #CheckAuth
export -f CheckAuth

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:56 CST 2017 - dscudiero - General syncing of dev to prod
