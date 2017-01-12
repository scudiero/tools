## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.8" # -- dscudiero -- 01/12/2017 @  7:09:18.08
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
		[[ -z $sqlStmt ]] && unset resultSet && return 0
		[[ ${sqlStmt:${#sqlStmt}:1} != ';' ]] && sqlStmt="$sqlStmt;"
		local stmtType=$(tr '[:lower:]' '[:upper:]' <<< "${sqlStmt%% *}")
		[[ -n $DOIT || $informationOnlyMode == true ]] && [[ $stmtType != 'SELECT' ]] && echo "sqlStmt = >$sqlStmt<" && return 0
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
			if [[ $(Contains "$resultStr" 'SEVERE:') == true || $(Contains "$resultStr" 'ERROR') == true ]]; then
				msg="$FUNCNAME: Error reported from $dbType"
				[[ $dbType == 'sqlite3' ]] && msg="$msg\n\tFile: $dbFile"
				msg="$msg\n\tsqlStmt: '$sqlStmt'\n\n\t$resultStr"
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
