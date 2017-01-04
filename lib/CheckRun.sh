#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.6" # -- dscudiero -- 01/04/2017 @ 13:36:49.53
#===================================================================================================
## Check to see if the current excution environment supports script execution
## Returns 1 in $? if user is authorized, otherwise it returns 0
## Always returns 1 if the script is not registerd in the scripts database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CheckRun {
	local script=${1:-$myName}
	local tempStr grepOut os host sqlStmt resultString
	GD echo "Starting: $FUNCNAME"

	## Check to see if the user is in the leepfrog group
		grepOut=$(cat /etc/group | grep leepfrog: | grep $userName)
		[[ grepOut == '' ]] && echo "Your userid ($userName) is not in the 'leepfrog' linux group.\nPlease contact the System Admin team and ask them to add you to the group." return 0

	## check to see if script is in the scripts table
		sqlStmt="select count(*) from $scriptsTable where name=\"$script\""
		RunSql 'mysql' $sqlStmt
		[[ ${resultSet[0]} -eq 0 ]] && echo true && return 0

	GD echo -e "\tChecking offline/inactive"
	## Check to see if the script is offline
		local offlineFileFound=false
		local scriptActive=true
		## Check to see if active flag is off
		GD echo -e "\t\tChecking active flag"
		sqlStmt="select active from $scriptsTable where name=\"$script\" and (host=\"$hostName\" or host is null) and (os=\"$osName\" or os is null)"
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			[[ ${resultSet[0]} != 'Yes' && ${resultSet[0]} != 'N/A' ]] && scriptActive=false
			GD echo -e "\t\t\t\${resultSet[0]} = >${resultSet[0]}<"
		fi
		[[ $scriptActive == false ]] && echo "Script '$script' is currently offline/inactive, please try again later." && return 0

		## Look for offline file
		GD echo -e "\t\tChecking for offline file"
		[[ ${script:${#script}-3:3} != '.sh' ]] && tempStr="${script}.sh" || tempStr=$script
		[[ -f $TOOLSPATH/${tempStr}-offline ]] && offlineFileFound=true
		GD echo -e "\t\t\tofflineFileFound = >$offlineFileFound<"
		[[ $offlineFileFound == true ]] && echo "Script '$script' is currently offline for maintenance, please try again later." && return 0


	GD echo -e "\tChecking env"
	## check host and os information
		sqlStmt="select os,host from $scriptsTable where name=\"$script\" and (host=\"$hostName\" or host is null) and (os=\"$osName\" or os is null)"
		RunSql 'mysql' $sqlStmt
		[[ ${#resultSet[@]} -ne 0 ]] && echo true && return 0

	## return message
		echo "Script is not supported in the current environment."
		sqlStmt="select os,host from $scriptsTable where name=\"$script\""
		RunSql 'mysql' $sqlStmt
		resultString=${resultSet[0]}
		resultString=$(echo "$resultString" | tr "\t" "|" )
		os=$(echo $resultString | cut -d '|' -f 1)
		host=$(echo $resultString | cut -d '|' -f 2)
		echo -e "\tScript execution is restricted to:"
		[[ $os != NULL ]] && echo -e "\t\tos = '$os'"
		[[ $host != NULL ]] && echo -e "\t\thost = '$host'"

	return 0
} #CheckRun
export -f CheckRun

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:58 CST 2017 - dscudiero - General syncing of dev to prod
