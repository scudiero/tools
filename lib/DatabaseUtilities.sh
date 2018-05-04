## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.41" # -- dscudiero -- Fri 05/04/2018 @ 10:02:48.52
#===================================================================================================
# Various data manipulation functions for database things
#===================================================================================================
# Copyright 2018 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

#============================================================================================================================================
# Return a list of column names defined for the passed in table along with a count
# Usage: getTableColumns <table> <database> [<return count variable name>] [<return columns variable name>]
#	<table> is the name of the table to retrieve data from
#	<database> is either 'warehouse' for the data warehouse or the filename of a sqlite file
# 	<return count variable name> defaults to 'numColumns'
#	<return columns variable name> defaults to 'columns'
# E.G.
#	getTableColumns 'contacts' "$contactsSqliteFile" 'numFields' 'fields'
#	getTableColumns 'sites' "warehouse" 'numFields' 'fields'
#============================================================================================================================================
function getTableColumns {
	Import 'SetFileExpansion RunSql'

	local table="$1"; shift || true
	local database="$1"; shift || true
	local returnCountVar="${1:-numColumns}"; shift || true
	local returnColumnsVar="${1:-columns}"; shift || true
	local sqlStmt columns column ifsSave tmpArray count
	dump 3 table database returnColumnsVar returnCountVar

	SetFileExpansion 'off'
	if [[ $database == 'warehouse' ]]; then
		sqlStmt="select column_name from information_schema.columns where table_name=\"$table\""
		RunSql $sqlStmt
		[[ ${#resultSet[@]} -le 0 || -z ${resultSet[0]} ]] && Terminate "Could not retrieve '$table' definition data from '$database'"
		eval "$returnCountVar=\"${#resultSet[@]}\""
		unset columns
		local i
		for ((i=0; i<${#resultSet[@]}; i++)); do
			columns="$columns,${resultSet[$i]}"
		done
	else
		if [[ -f "$database" ]]; then
			sqlStmt="select * from sqlite_master where type=\"table\" and name=\"$table\""
			RunSql "$database" $sqlStmt
			[[ ${#resultSet[@]} -le 0 || -z ${resultSet[0]} ]] && Terminate "Could not retrieve '$table' definition data from '$database'"
			unset columns
			## If only one row returned then we just have a list of columns,
			if [[ ${#resultSet[@]} -eq 1 ]]; then
				data="${resultSet[0]#*(}"; data="${data%)*}"
				ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$data"
				count=${#tmpArray[@]}
				for column in "${tmpArray[@]}"; do
					[[ ${column:0:1} == ' ' ]] && column="${column:1}"
			    	columns="$columns,${column%% *}"
				done
			else
				## otherwise it is an array with each field on its own record
				for ((i=1; i<${#resultSet[@]}-1; i++)); do
					column="${resultSet[$i]}"; column="${column:1}"; column="${column%%|*}"; column="${column//\`/}"
					columns="$columns,${column%% *}"
				done
				let count=${#resultSet[@]}-2
			fi
		fi
	fi
	SetFileExpansion

	columns="${columns:1}"
	eval "$returnColumnsVar=\"\$columns\""
	eval "$returnCountVar=\"$count\""

	return 0
} #getTableColumns
export -f getTableColumns

#===================================================================================================
# Check-in Log
#===================================================================================================
## 05-04-2018 @ 09:51:42 - 1.0.37 - dscudiero - Fix problem for sqlite databases someting returning one record and sometimes on record per column
## 05-04-2018 @ 09:58:09 - 1.0.39 - dscudiero - Fix variable name columncolumn -> column
## 05-04-2018 @ 10:03:21 - 1.0.41 - dscudiero - Fix bug setting count value for sqlite multiple records
