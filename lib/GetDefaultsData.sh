## XO NOT AUTOVERSION
#===================================================================================================
# version="2.0.14" # -- dscudiero -- 01/04/2017 @ 13:39:35.35
#===================================================================================================
# Get default variable values from the defaults database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function GetDefaultsData {
	Verbose 3 "*** Starting $FUNCNAME ***"
	local scriptName="$1"

	## Set myPath based on if the current file has been sourced
		[[ -d $(dirname ${BASH_SOURCE[0]}) ]] && myPath=$(dirname ${BASH_SOURCE[0]})

		if [[ $scriptName == '' || $defaultsLoaded != true ]]; then
			# echo "Loading global defaults"
			Msg2 $V3 "$FUNCNAME: Loading common values..."
			dbFields="name,value"
			whereClause="(os=\"$osName\" or os is null) and (host=\"$hostName\" or host is null) and status=\"A\""
			sqlStmt="select $dbFields from defaults where $whereClause order by name,host"
			RunSql 'mysql' $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				Msg2 $T "Could not retrieve common defaults data from the $mySqlDb.defaults table."
			else
				recCntr=0
				while [[ $recCntr -lt ${#resultSet[@]} ]]; do
					varName=$(cut -d'|' -f1 <<< ${resultSet[$recCntr]})
					## If the variable does not already has a value, then set from the db data
					[[ ${!varName} == '' ]] && eval $varName=\"$(cut -d '|' -f 2-  <<< ${resultSet[$recCntr]})\"
					(( recCntr += 1 ))
				done
			fi
			## Get last viewed news eDate
			sqlStmt="select edate from $newsInfoTable where userName=\"$userName\" and object=\"$scriptName\" "
			RunSql 'mysql' $sqlStmt
			[[ ${#resultSet[@]} -gt 0 ]] && lastViewedScriptNewsEdate=$(cut -d '|' -f2 <<< ${resultSet[0]})
		fi

	## Get script specific data from the script record in the scripts database
		# echo "Loading script specific defaults"
		fields='scriptData1,scriptData2,scriptData3,scriptData4,scriptData5,ignoreList,allowList,emailAddrs'
		unset $(tr ',' ' ' <<< $fields)
		sqlStmt="select $fields from $scriptsTable where name=\"$scriptName\""
		RunSql 'mysql' $sqlStmt
		if [[ ${#resultSet[@]} -ne 0 ]]; then
			fieldCntr=1
			for field in $(tr ',' ' ' <<< $fields); do
				eval $field=\"$(cut -d '|' -f $fieldCntr <<< "${resultSet[0]}")\"
				[[ ${!field} == 'NULL' ]] && eval unset $field
				(( fieldCntr += 1 ))
			done
		fi

	Verbose 3 "*** Ending $FUNCNAME ***"
	return 0
} #GetDefaultsData
export -f GetDefaultsData

#===================================================================================================
# Check-in Log
#===================================================================================================
## Wed Jan  4 13:53:34 CST 2017 - dscudiero - General syncing of dev to prod
