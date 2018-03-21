## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.2" # -- dscudiero -- Wed 03/21/2018 @  7:33:44.68
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
function RunSql {
	Import SetFileExpansion
	function MyContains { local string="$1"; local subStr="$2"; [[ "${string#*$subStr}" != "$string" ]] && echo true || echo false; return 0; }

	local dbType='mysql'
	if [[ ${1:0:1} == '/' ]]; then
		local dbFile="$1" && shift
		local dbType='sqlite3'
	fi
	local sqlStmt="$*"
	[[ -z $sqlStmt ]] && Terminate "$FUNCNAME called with no sql statement specified"
	local javaPgm=${runMySqlJavaPgmName:-runMySql}

	local sqlAction="${sqlStmt%% *}"
	[[ ${sqlAction:0:5} != 'mysql' && ${sqlStmt:${#sqlStmt}:1} != ';' ]] && sqlStmt="$sqlStmt;"

	local calledBy=$(caller 0 | cut -d' ' -f2)
	if [[ -n $DOIT || $informationOnlyMode == true ]]; then
		local stmtType="${sqlStmt%% *}"; stmtType="${stmtType^^[a-z]}"
		[[ $stmtType != 'SELECT' && $calledBy != 'ProcessLogger' ]] && Msg3 "$sqlStmt"
		return 0
	fi

	# ## Run the query, put output into the resultSet array
		SetFileExpansion 'off'
		unset resultSet
	 	if [[ $dbType == 'mysql' ]]; then
	 		jar="$TOOLSPATH/jars/$javaPgm.jar"
	 		[[ $useLocal == true && -f $HOME/tools/jars/$javaPgm.jar ]] && jar="$HOME/tools/jars/$javaPgm.jar"
	 		readarray -t resultSet <<< "$(java -jar $jar $sqlStmt 2>&1)"
	 	else
	 		[[ ! -f $dbFile ]] && Terminate "Could not locate the sqlite file:\n^$dbFile"
	 		readarray -t resultSet <<< "$(sqlite3 $dbFile "$sqlStmt" 2>&1 | tr "\t" '|')"
	 	fi
		SetFileExpansion

 	## Check for errors
	 	if [[ ${#resultSet[@]} -gt 0 ]]; then
	 		[[ ${resultSet[0]} =~ .*\*Error\**. ]] && Terminate "${resultSet[0]}\n^${resultSet[1]}\n^${resultSet[2]}"
	 	fi

	return 0
} #RunSql

function RunSql2 { RunSql $*  ; return 0; }
export -f RunSql RunSql2

#===================================================================================================
# Check-in Log
#===================================================================================================
## 03-20-2018 @ 17:36:20 - 1.0.1 - dscudiero - Added defining RunSql2 function
## 03-21-2018 @ 07:34:01 - 1.0.2 - dscudiero - Fix problem setting default jar path