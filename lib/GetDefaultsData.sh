## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.28" # -- dscudiero -- 01/13/2017 @ 15:14:53.96
#===================================================================================================
# Get default variable values from the defaults database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function GetDefaultsData {
	Verbose 3 "*** Starting $FUNCNAME ***"
echo "$FUNCNAME Starting"

	local scriptName="$1" ; shift || true
	local table="${1:-$scriptsTable}"
	local sqlStmt dbFields fields field fieldCntr varName whereClause

	## Set myPath based on if the current file has been sourced
		[[ -d $(dirname ${BASH_SOURCE[0]}) ]] && myPath=$(dirname ${BASH_SOURCE[0]})

		if [[ $defaultsLoaded != true ]]; then
echo "Loading global defaults"
			Msg2 $V3 "$FUNCNAME: Loading common values..."
			dbFields="name,value"
			whereClause="(os=\"$osName\" or os is null) and (host=\"$hostName\" or host is null) and status=\"A\""
			sqlStmt="select $dbFields from defaults where $whereClause order by name,host"
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				Msg2 $T "Could not retrieve common defaults data from the $mySqlDb.defaults table."
			else
				recCntr=0
				while [[ $recCntr -lt ${#resultSet[@]} ]]; do
					varName=$(cut -d'|' -f1 <<< ${resultSet[$recCntr]})
echo -e "\tvarName='$varName'"
					[[ -z $varName ]] && continue
					## If the variable does not already has a value, then set from the db data
echo -e "\tvarValue='$(cut -d '|' -f 2-  <<< ${resultSet[$recCntr]})'"
					[[ ${!varName} == '' ]] && eval $varName=\"$(cut -d '|' -f 2-  <<< ${resultSet[$recCntr]})\"
					(( recCntr += 1 ))
				done
			fi
			## Get last viewed news eDate
			sqlStmt="select edate from $newsInfoTable where userName=\"$userName\" and object=\"$scriptName\" "
			RunSql2 $sqlStmt
			[[ ${#resultSet[@]} -gt 0 ]] && lastViewedScriptNewsEdate=$(cut -d '|' -f2 <<< ${resultSet[0]})
			defaultsLoaded=true
		fi

	## Get script specific data from the script record in the scripts database
		if [[ -n $scriptName ]]; then
echo "Loading $scriptName defaults"
			if [[ $table == $scriptsTable ]]; then
				fields='scriptData1,scriptData2,scriptData3,scriptData4,scriptData5,ignoreList,allowList,emailAddrs'
			else
				fields='ignoreList,allowList'
			fi
echo -e "\tfields='$fields'"
			unset $(tr ',' ' ' <<< $fields)
			sqlStmt="select $fields from $table where name=\"$scriptName\""
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				fieldCntr=1
				for field in $(tr ',' ' ' <<< $fields); do
echo -e "\t\tfield='$field'"
echo -e "\t\tvalue='$(cut -d '|' -f $fieldCntr <<< "${resultSet[0]}")'"

					eval $field=\"$(cut -d '|' -f $fieldCntr <<< "${resultSet[0]}")\"
					[[ ${!field} == 'NULL' ]] && eval unset $field
					(( fieldCntr += 1 ))
				done
			fi
		fi
echo "$FUNCNAME Done"
	Verbose 3 "*** Ending $FUNCNAME ***"
	return 0
} #GetDefaultsData
export -f GetDefaultsData

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:34 CST 2017 - dscudiero - General syncing of dev to prod
## Thu Jan 12 14:38:36 CST 2017 - dscudiero - Update to add ability to pass in the table to load defaults from
## Fri Jan 13 06:59:57 CST 2017 - dscudiero - Set defaultsLoaded variable
## Fri Jan 13 09:23:19 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan 13 15:15:16 CST 2017 - dscudiero - Add debug statements
