## XO NOT AUTOVERSION
#===================================================================================================
# version="1.0.29" # -- dscudiero -- Wed 07/18/2018 @ 12:01:29
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
	## If infoMode and not a 'select' then skip it

	if [[ -n $DOIT || $informationOnlyMode == true ]]; then
		local stmtType="${sqlStmt%% *}"; stmtType="${stmtType^,,[a-z]}"
		[[ $stmtType != 'select' && $calledBy != 'ProcessLogger' ]] && { Msg "$sqlStmt" ; Here rs0; return 0; }
	fi

	# ## Run the query, put output into the resultSet array
		SetFileExpansion 'off'
		unset resultSet
	 	if [[ $dbType == 'mysql' ]]; then
	 		jar="$TOOLSPATH/jars/$javaPgm.jar"
	 		[[ $useDev == true && -f $TOOLSDEVPATH/jars/$javaPgm.jar ]] && jar="$TOOLSDEVPATH/jars/$javaPgm.jar"
	 		[[ $useLocal == true && -f $HOME/tools/jars/$javaPgm.jar ]] && jar="$HOME/tools/jars/$javaPgm.jar"
	 		readarray -t resultSet <<< "$(java -jar $jar $sqlStmt 2>&1)"
	 	else
	 		[[ ! -f $dbFile ]] && Terminate "Could not locate the sqlite file:\n^$dbFile"
	 		readarray -t resultSet <<< "$(sqlite3 $dbFile "$sqlStmt" 2>&1 | tr "\t" '|')"
	 	fi
		SetFileExpansion

 	## Check for errors
	 	if [[ ${#resultSet[@]} -gt 0 ]]; then
	 		if [[ ${resultSet[0]} =~ .*\*Error\**. || ${resultSet[0]} =~ .*Exception*. ]]; then
	 			Error "Error encountered in '$FUNCNAME' processing '${dbType^^[a-z]}' call, messages follow:"
				for ((i=0; i<${#resultSet[@]}; i++)); do
					echo "     ${resultSet[$i]}"
				done
	 			Terminate "Error encountered in '$FUNCNAME' processing '${dbType^^[a-z]}' call"
	 		fi
	 	fi

	return 0
} #RunSql

export -f RunSql

#===================================================================================================
# Check-in Log
#===================================================================================================
## 03-20-2018 @ 17:36:20 - 1.0.1 - dscudiero - Added defining RunSql2 function
## 03-21-2018 @ 07:34:01 - 1.0.2 - dscudiero - Fix problem setting default jar path
## 03-21-2018 @ 15:38:26 - 1.0.3 - dscudiero - Add more robust error checking
## 03-21-2018 @ 15:42:08 - 1.0.4 - dscudiero - Cosmetic/minor change/Sync
## 03-23-2018 @ 17:04:30 - 1.0.5 - dscudiero - Msg3 -> Msg
## 03-26-2018 @ 09:01:07 - 1.0.6 - dscudiero - Remove RunSql2 definition
## 03-26-2018 @ 09:12:09 - 1.0.7 - dscudiero - Cosmetic/minor change/Sync
## 04-18-2018 @ 09:35:54 - 1.0.8 - dscudiero - Added toolsdev support
## 04-18-2018 @ 09:38:01 - 1.0.9 - dscudiero - Use the TOOLSDEVPATH variable
## 04-19-2018 @ 08:11:01 - 1.0.10 - dscudiero - Tweak statement setting jar file if useDev
## 05-22-2018 @ 14:07:39 - 1.0.28 - dscudiero - Fix problem with information only mode
## 07-18-2018 @ 12:02:48 - 1.0.29 - dscudiero - Switch to use echo vs Msg for errors
