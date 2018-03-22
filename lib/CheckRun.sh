#!/bin/bash

## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.14" # -- dscudiero -- Thu 03/22/2018 @ 13:36:09.32
#===================================================================================================
## Check to see if the current excution environment supports script execution
## Returns 1 in $? if user is authorized, otherwise it returns 0
## Always returns 1 if the script is not registerd in the scripts database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function CheckRun {
	Import 'RunSql'
	local script=${1:-$myName}
	local tempStr grepOut os host sqlStmt resultString

	## Check to see if the user is in the leepfrog group
		grepOut=$(cat /etc/group | grep leepfrog: | grep $userName)
		[[ grepOut == '' ]] && echo "Your userid ($userName) is not in the 'leepfrog' linux group.\nPlease contact the System Admin team and ask them to add you to the group." return 0

	## Check to see if the script is offline
		local offlineFileFound=false
		local scriptActive=true
		## Check to see if active flag is off
		sqlStmt="select active from $scriptsTable where name=\"$script\" and (host=\"$hostName\" or host is null) and (os=\"$osName\" or os is null)"
		RunSql $sqlStmt
		[[ ${#resultSet[@]} -eq 0 ]] && echo true && return 0 ## Not in the table
		[[ ${resultSet[0]} != 'Yes' && ${resultSet[0]} == 'N/A' ]] && echo "Script '$script' is currently offline/inactive, please try again later." && return 0

		echo true
		return 0 
} #CheckRun
export -f CheckRun

#===================================================================================================
# Checkin Log
#===================================================================================================

## Wed Jan  4 13:52:58 CST 2017 - dscudiero - General syncing of dev to prod
## 05-05-2017 @ 13.45.20 - ("2.0.8")   - dscudiero - General syncing of dev to prod
## 05-09-2017 @ 13.57.17 - ("2.0.10")  - dscudiero - Refactored to improve performance
## 09-06-2017 @ 14.14.46 - ("2.0.11")  - dscudiero - Updateed to check if active is not Yes and not N/A
## 09-29-2017 @ 13.29.43 - ("2.0.12")  - dscudiero - Include RunSql
## 09-29-2017 @ 13.30.36 - ("2.0.13")  - dscudiero - General syncing of dev to prod
## 03-22-2018 @ 13:41:58 - 2.0.14 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
