## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.18" # -- dscudiero -- 12/12/2016 @ 15:00:17.41
#===================================================================================================
# Run a statement
# <sqlType> <sqlFile> <sql>
# Where:
# 	<sqlType> 	in {'mysql','sqlite'}
# 	<sqlFile> 	is valid only for sqlite
# 	<sql> 		The sql statement to run
# returns data in an array called 'resultSet'
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function RunSql {
	SetFileExpansion 'off'
	local type=$(Lower "$1")
	[[ $type != 'mysql' && $type != 'sqlite' ]] && type='mysql' || shift
	[[ $type == 'sqlite' ]] && local dbFile="$1" && shift
	local sqlStmt="$*"
	[[ ${sqlStmt:${#sqlStmt}:1} != ';' ]] && sqlStmt="$sqlStmt;"

	local validSqlTypes='select insert delete update pragma'
	local adminOnlySqlTypes='truncate'
	local readOnlySqlTypes='select'
	local sqlCmdString mySqlConnectStringSave dbAcc
	local stmtType=$(Lower $(echo $sqlStmt | cut -d' ' -f1))

	if [[ $type == 'mysql' ]]; then
		[[ $mySqlConnectString == '' ]] && Msg2 $T "Could not resolve mysql connection information to '$warehouseDb'\n^^$sqlStmt"
		validSqlTypes="$validSqlTypes show"
		[[ $(Contains ",${administrators}," ",$userName,") == true ]] && validSqlTypes="$validSqlTypes truncate"
		[[ $(Contains "$validSqlTypes" "$stmtType") != true ]] &&  Msg2 $T "$FUNCNAME: Unknown SQL statement type '$stmtType'\n\tSql: $sql"
		[[ $DOIT != '' && $(Contains "$readOnlySqlTypes" "$stmtType") != true ]] && echo "sqlStmt = >$sqlStmt<" && return 0
		## Override access level
		if [[ $(Contains "$readOnlySqlTypes" "$stmtType") != true ]]; then
			mySqlConnectStringSave="$mySqlConnectString";
			[[ $(Contains "$adminOnlySqlTypes" "$stmtType") == true ]] && dbAcc="Admin" || dbAcc='Update'
			mySqlConnectString=$(sed "s/Read/$dbAcc/" <<< $mySqlConnectString)
		fi
		sqlCmdString="mysql --skip-column-names --batch $mySqlConnectString -e "
	else
		sqlCmdString="sqlite3 $dbFile"
		validSqlTypes="$validSqlTypes .dump"
	fi

	## Run the query
	unset resultStr resultSet
	resultStr=$($sqlCmdString "$sqlStmt" 2>&1 | tr "\t" '|')
	local tmpStr="$(echo $resultStr | cut -d' ' -f1)"
	if [[ $(Upper "${tmpStr:0:5}") == 'ERROR' ]]; then
		[[ $type == 'mysql' ]] && Terminate "$(ColorK "$myName").$FUNCNAME: Error returned from $type:\n\tDatabase: $warehouseDb\n\tSql: $sqlStmt\n\t$resultStr"
		[[ $type == 'sqlite' ]] && Terminate "$(ColorK "$myName").$FUNCNAME: Error returned from sqlite3:\n\tFile: $dbFile\n\tSql: $sqlStmt\n\t$resultStr"
	fi
	[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<<"$resultStr"

	[[ $mySqlConnectStringSave != '' ]] && mySqlConnectString="$mySqlConnectStringSave"
	SetFileExpansion
	return 0
} ##RunSql
export -f RunSql

#===================================================================================================
# Check-in Log
#===================================================================================================

