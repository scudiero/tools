#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.93" # -- dscudiero -- Mon 11/05/2018 @ 09:59:53
#===================================================================================================
# Check to see if the logged user can run this script
# Returns true if user is authorized, otherwise it returns a message
# Always returns true if the script is not registerd in the scripts database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function CheckAuth {
	## Do we have the auth data loaded to memory
	if [[ -z $UsersScriptsStr || -z $UsersScripts || -z UsersScripts ]]; then
			## Get the employeeKey for this user
		sqlStmt="select employeekey from $employeeTable where userid=\"$userName\""
		RunSql $sqlStmt
		employeeKey="${resultSet[0]}"
		Verbose 1 "^^EmployeeKey: $employeeKey"

		## Get the list of groups this user is in
		sqlStmt="select groupId,code from $authGroupTable where groupId in (select authKey from auth2user where 
				empKey=$employeeKey)"
		RunSql $sqlStmt
		unset groupListStr UsersAuthGroups
		for result in "${resultSet[@]}"; do groupListStr="$groupListStr,$result"; done
		groupListStr="${groupListStr:1}"
		[[ -z $groupListStr ]] && continue
		UsersAuthGroups="${groupListStr//,/, }"
		Verbose 1 "^^Groups: $UsersAuthGroups"

		## Get the list of scripts this user has access to, add them to the file
		# 1) Scripts authorized to a group that the user is a member of (auth2user, auth2script)
		# 2) Scripts where the user has specifically been granted access to (user2scripts)
		# 3) Unrestricted scripts
		sqlStmt="select distinct keyId,name,description,shortDescription,showInScripts from $scriptsTable where (keyId in \
		((select scriptKey from auth2script where groupKey in \
		(select authKey from auth2user where empKey in \
		(select employeekey from employee where substr(email,1,instr(email,'@')-1)=\"$userName\"))))\
		or \
		(keyId in (select scriptKey from user2script where empKey in \
		(select employeekey from employee where substr(email,1,instr(email,'@')-1)=\"$userName\")))) \
		or \
		(keyId not in (select scriptKey from auth2script) and keyId not in  (select scriptKey from user2script))
		and \
		name not in (\"loader\",\"dispatcher\")
		order by name"
		RunSql $sqlStmt

		## Generate a comma separated list of script names
		Verbose 2 "^^Found ${#resultSet[@]} script records..."
		[[ ${#resultSet[@]} -eq 0 || ${resultSet[0]} == "" ]] && continue
		unset UsersScriptsStr UsersScripts
		for result in "${resultSet[@]}"; do
			scriptId="${result%%|*}"; result="${result#*|}"; 
			Verbose 2 "^^^$result"
			UsersScripts+=("${scriptId}|${result}")
			UsersScriptsStr="$UsersScriptsStr,${scriptId}|${result%%|*}"
		done
		UsersScriptsStr="${UsersScriptsStr:1}"
	fi
	
	## Check to make sure we are authorized
		local scriptName=${1-$myName}
		if [[ $scriptName != 'scripts' && $scriptName != 'testsh' ]]; then
			if [[ $(Contains ",$UsersScriptsStr," ",$scriptName,") != true ]] && [[ $(Contains "$UsersScriptsStr," "|$scriptName,") != true ]]; then
				unset grpPrtStr; for group in $UsersAuthGroups; do grpPrtStr="$grpPrtStr ${group##*|}"; done
				echo; echo; Terminate "Sorry, you do not have authorization to run script '$scriptName'. \
				You are in the following authorization groups: \n\t\t\t${grpPrtStr}.  \
				\n\t\t Please contact your supervisor or '$administrators' for additional information.";
			fi
		fi

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
## 02-02-2018 @ 09.25.58 - 2.0.40 - dscudiero - Fix problem not seeing first token in the restrictToGroups string
## 02-02-2018 @ 09.26.40 - 2.0.41 - dscudiero - Comment out the author check
## 02-02-2018 @ 09.28.26 - 2.0.42 - dscudiero - Cosmetic/minor change/Sync
## 02-02-2018 @ 09.44.36 - 2.0.46 - dscudiero - Fix bug checking of the auth file existrs
## 03-22-2018 @ 13:41:52 - 2.0.47 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 04-19-2018 @ 15:19:08 - 2.0.48 - dscudiero - Re-factore checking sql query results = 0
## 05-10-2018 @ 11:04:10 - 2.0.49 - dscudiero - Turn on the author check again
## 05-25-2018 @ 11:41:36 - 2.0.69 - dscudiero - Re-factor to use the ScriptAuthData hash
## 05-25-2018 @ 15:02:04 - 2.0.73 - dscudiero - Fix problem with false positives if there is no restricttogroup data
## 11-05-2018 @ 10:14:08 - 2.0.93 - dscudiero - Switch to use the database and new auth structures
