## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.1" # -- dscudiero -- 01/05/2017 @ 13:46:40.93
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
		local sqlStmt="$*" ; [[ ${sqlStmt:${#sqlStmt}:1} != ';' ]] && sqlStmt="$sqlStmt;"
		local stmtType=$(tr '[:lower:]' '[:upper:]' <<< "${sqlStmt%% *}")
		[[ -n $DOIT || $informationOnlyMode == true ]] && [[ $stmtType != 'SELECT' ]] && echo "sqlStmt = >$sqlStmt<" && return 0
		local prevGlob=$(set -o | grep noglob | tr "\t" ' ' | tr -s ' ' | cut -d' ' -f2)
		local resultStr msg tmpStr

		## Run the query
			set -f
			[[ $dbType == 'mysql' ]] && resultStr=$(java runMySql $sqlStmt) || resultStr=$(sqlite3 $dbFile "$sqlStmt" 2>&1 | tr "\t" '|')
			tmpStr="${resultStr%% *}"
			if [[ $(tr '[:lower:]' '[:upper:]' <<< "${tmpStr:0:5}") == 'ERROR' ]]; then
				msg="$FUNCNAME: Error reported from $dbType"
				[[ $dbType == 'sqlite3' ]] && msg="$msg\n\tFile: $dbFile"
				msg="$msg\n\tsqlStmt: $sqlStmt"
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
