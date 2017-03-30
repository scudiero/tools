## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.20" # -- dscudiero -- Thu 03/30/2017 @  8:39:31.96
#===================================================================================================
# Run a statement
# [sqlFile] sql
# Where:
# 	sqlFile 	If the first token is a file name then it is assumed that this is a sqlite request,
#				otherwise it will be treated as a mysql request
# 	sql 		The sql statement to run
# returns data in an array called 'resultSet'
#===================================================================================================
# Copyright 2017 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

	function RunSql2 {
		if [[ ${1:0:1} == '/' ]]; then
			local dbFile="$1" && shift
			local dbType='sqlite3'
		else
			local dbType='mysql'
		fi
		local sqlStmt="$*"
		unset resultSet

		[[ -z $sqlStmt ]] && return 0
		local sqlAction="${sqlStmt%% *}"
		[[ ${sqlAction:0:5} != 'mysql' && ${sqlStmt:${#sqlStmt}:1} != ';' ]] && sqlStmt="$sqlStmt;"
		local stmtType=$(tr '[:lower:]' '[:upper:]' <<< "${sqlStmt%% *}")

		local calledBy=$(caller 0 | cut -d' ' -f2)
		[[ -n $DOIT || $informationOnlyMode == true ]] && [[ $stmtType != 'SELECT' && $calledBy != 'ProcessLogger' ]] && return 0

		local prevGlob=$(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
		local resultStr msg tmpStr

		## Run the query
			set -f
			if [[ $dbType == 'mysql' ]]; then
				resultStr=$(java runMySql $sqlStmt 2>&1)
			else
				resultStr=$(sqlite3 $dbFile "$sqlStmt" 2>&1 | tr "\t" '|')
			fi
			## Check for errors
			if [[ $(Contains "$resultStr" 'SEVERE:') == true || $(Contains "$resultStr" 'ERROR') == true || $(Contains "$resultStr" '\*Error\*') == true ]]; then
				msg="$FUNCNAME: Error reported from $dbType"
				[[ $dbType == 'sqlite3' ]] && msg="$msg\n\tFile: $dbFile"
				msg="$msg\n\tsqlStmt: $sqlStmt\n\n\t$resultStr"
				if [[ $(type -t 'Terminate') == function ]]; then
					Terminate "$(ColorK "$myName").$msg"
				else
					echo "*Fatal Error* -- $msg"
					exit -1
				fi
			fi

		## Write output to an array
			unset resultSet
			[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<<"$resultStr"
			[[ $prevGlob == 'on' ]] && set +f

		return 0
	} #RunMySql
	export -f RunSql2

#===================================================================================================
# Check-in Log
#===================================================================================================
## Thu Jan  5 13:47:13 CST 2017 - dscudiero - add a kill switch if informationOnly flag is set
## Wed Jan 11 15:52:04 CST 2017 - dscudiero - Fix error processing if java throws an error
## Thu Jan 12 07:11:32 CST 2017 - dscudiero - Add a blank line between message and command output when an error is detected
## Tue Jan 17 08:58:15 CST 2017 - dscudiero - Add check for *Error* coming back from sql query
## Wed Jan 18 13:09:24 CST 2017 - dscudiero - Return immediatly if informationonly is on
## Wed Jan 18 13:13:30 CST 2017 - dscudiero - General syncing of dev to prod
## Wed Jan 18 13:37:13 CST 2017 - dscudiero - misc cleanup
## Tue Jan 24 07:31:39 CST 2017 - dscudiero - Allow function to run if called by ProcessLogger and informationOnly is set
## 03-30-2017 @ 08.40.53 - ("1.0.20")  - dscudiero - Do not add trailing ';' if the sql action is mysql*
