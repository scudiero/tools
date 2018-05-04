## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.36" # -- dscudiero -- Fri 05/04/2018 @  9:03:32.85
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
	local sqlStmt columns token ifsSave tmpArray

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
			data="${resultSet[0]#*(}"; data="${data%)*}"
			ifsSave="$IFS"; IFS=',' read -ra tmpArray <<< "$data"
			eval "$returnCountVar=\"${#tmpArray[@]}\""
			for token in "${tmpArray[@]}"; do
				[[ ${token:0:1} == ' ' ]] && token="${token:1}"
		    	columns="$columns,${token%% *}"
			done
		fi
	fi
	SetFileExpansion

	columns="${columns:1}"
	eval "$returnColumnsVar=\"\$columns\""

	return 0
} #getTableColumns

export -f getTableColumns

#===================================================================================================
# Check-in Log
#===================================================================================================
