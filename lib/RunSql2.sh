## XO NOT AUTOVERSION
#===================================================================================================
# version="1.1.2" # -- dscudiero -- Mon 10/16/2017 @ 13:33:06.46
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

	function MyContains {
		local string="$1"
		local subStr="$2"
		[[ "${string#*$subStr}" != "$string" ]] && echo true || echo false
		return 0
	}

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
	if [[ ! -d $(pwd) ]]; then
		msg="$msg\n\tsqlStmt: $sqlStmt\n\n\tCurrent working directory does not exist, cannot execute sql statement"
		echo -e "$(ColorT "*Fatal Error*") -- ($lineNo) $msg"
		exit -1
	fi

	## Run the query
		set -f
		[[ $dbType == 'mysql' ]] && resultStr="$(java runMySql $sqlStmt 2>&1)" || resultStr="$(sqlite3 $dbFile "$sqlStmt" 2>&1 | tr "\t" '|')"
 		[[ $prevGlob == 'on' ]] && set +f
 		## Check for errors
 		##local tmpStr="$(tr '[:upper:]' '[:lower:]' <<< "$resultStr")" 
		if [[ $(MyContains "$resultStr" 'sever:') == true || $(MyContains "$resultStr" 'ERROR' == true) == true || \
			  $(MyContains "$resultStr" '\*Error\*') == true || $(MyContains "$resultStr" 'Error' == true) == true ]]; then
			local callerData="$(caller)"
			local lineNo="$(basename $(cut -d' ' -f2 <<< $callerData))/$(cut -d' ' -f1 <<< $callerData)"
			msg="$FUNCNAME: Error reported from $dbType"
			[[ $dbType == 'sqlite3' ]] && msg="$msg\n\tFile: $dbFile"
			msg="$msg\n\tsqlStmt: $sqlStmt\n\n\t$resultStr"
			echo -e "$(ColorT "*Fatal Error*") -- ($lineNo) $msg"
			return -3
		fi
 	## Write output to an array
		unset resultSet
		#[[ $resultStr != '' ]] && IFS=$'\n' read -rd '' -a resultSet <<< "$resultStr"
		[[ $resultStr != '' ]] && readarray -t resultSet <<< "${resultStr}"

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
## 06-26-2017 @ 10.13.49 - ("1.0.36")  - dscudiero - Add additional error checking for VM errors
## 10-02-2017 @ 17.06.49 - ("1.1.-1")  - dscudiero - Check results after call pf python pgm
## 10-03-2017 @ 14.45.06 - ("1.1.-1")  - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.46.58 - ("1.1.-1")  - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.50.14 - ("1.1.-1")  - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.51.22 - ("1.1.-1")  - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 14.56.04 - ("1.1.-1")  - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 15.46.14 - ("1.1.-1")  - dscudiero - Update how we set the return array
## 10-04-2017 @ 12.47.32 - ("1.1.-1")  - dscudiero - Regress to the old parsing method
## 10-11-2017 @ 09.32.00 - ("1.1.-1")  - dscudiero - Update to use readarrau to parse output string to resutSet array
## 10-12-2017 @ 14.26.05 - ("1.1.0")   - dscudiero - Use readarray to build the resultSet array
## 10-16-2017 @ 13.33.30 - ("1.1.2")   - dscudiero - Update the error detection code to be a bit less sensitive
