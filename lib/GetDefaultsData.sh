## DO NOT AUTOVERSION
#===================================================================================================
# version="2.1.-1" # -- dscudiero -- Fri 09/29/2017 @ 13:43:00.02
#===================================================================================================
# Get default variable values from the defaults database
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================
function GetDefaultsData {
	## Defaults ====================================================================================
	local mode='fromDb'
	local table='scripts'
	local scripts; unset scripts

	## Parse arguments =============================================================================
	## '-f'		- pull data from defaults files
	## '-d'		- pull date from the warehouse (this is the default)
	## other parameters as below
	while [[ $# -gt 0 ]]; do
	    [[ $1 =~ ^-m|--mode$ ]] && { mode="'$2'"; shift 2; continue; }
	    [[ $1 =~ ^-f|--fromFiles$ ]] && { mode='fromFiles'; shift 1; continue; }
	    [[ $1 =~ ^-d|--Db$ ]] && { mode='fromDb'; shift 1; continue; }
	    [[ $1 =~ ^-r|--reports$ ]] && { table='reports'; shift 2; continue; }
	    [[ $1 =~ ^-s|--scripts$ ]] && { table='scripts'; shift 2; continue; }
	    scripts="$scripts $1"
	    shift 1 || true
	done
	scripts="${scripts:1}"

	## MAIN ========================================================================================
	## If mode is fromFiles then just source the defaults files from the shadows
	if [[ $mode == 'fromFiles' ]]; then
		[[ -f "$TOOLSDEFAULTSPATH/common" ]] && source "$TOOLSDEFAULTSPATH/common"
		[[ -f "$TOOLSDEFAULTSPATH/$hostName" ]] && source "$TOOLSDEFAULTSPATH/$hostName"
		if [[ -n $scripts ]]; then
			for scriptName in $scripts; do
				[[ -f "$TOOLSDEFAULTSPATH/$scriptName" ]] && source "$TOOLSDEFAULTSPATH/$scriptName"
			done
		fi
		return 0
	fi

	## Pull the data from the Db
	Import "RunSql2"
	local sqlStmt fields field fieldCntr varName whereClause
	scriptName="$scripts"

	## Load common default values
		if [[ $defaultsLoaded != true ]]; then
			whereClause="(os=\"$osName\" or os is null) and (host=\"$hostName\" or host is null) and status=\"A\""
			sqlStmt="select name,value from defaults where $whereClause"
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -eq 0 ]]; then
				Terminate "Could not retrieve common defaults data from the $warehouseDb.defaults table."
			else
				recCntr=0
				while [[ $recCntr -lt ${#resultSet[@]} ]]; do
					varName=$(cut -d'|' -f1 <<< ${resultSet[$recCntr]})
					[[ -z $varName ]] && continue
					## If the variable does not already has a value, then set from the db data
					[[ -z ${!varName} ]] && eval $varName=\"$(cut -d '|' -f 2-  <<< ${resultSet[$recCntr]})\"
					(( recCntr += 1 ))
				done
			fi
			## Get last viewed news eDate
			sqlStmt="select edate from $newsInfoTable where userName=\"$userName\" and object=\"$scriptName\" "
			RunSql2 $sqlStmt
			[[ ${#resultSet[@]} -gt 0 ]] && lastViewedScriptNewsEdate=$(cut -d '|' -f2 <<< ${resultSet[0]})
			defaultsLoaded=true
		fi

	## If scriptname was passed in then get script specific data from the script record in the scripts database
		if [[ -n $scriptName ]]; then
			if [[ $table == $scriptsTable ]]; then
				fields='scriptData1,scriptData2,scriptData3,scriptData4,scriptData5,ignoreList,allowList,emailAddrs,updatesClData'
			else
				fields='ignoreList,allowList'
			fi
			unset $(tr ',' ' ' <<< $fields)
			sqlStmt="select $fields from $table where name=\"$scriptName\""
			RunSql2 $sqlStmt
			if [[ ${#resultSet[@]} -ne 0 ]]; then
				fieldCntr=1
				for field in $(tr ',' ' ' <<< $fields); do
					eval $field=\"$(cut -d '|' -f $fieldCntr <<< "${resultSet[0]}")\"
					[[ ${!field} == 'NULL' ]] && eval unset $field
					(( fieldCntr += 1 ))
				done
			fi
		fi
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
## Fri Jan 13 15:21:55 CST 2017 - dscudiero - General syncing of dev to prod
## Fri Jan 13 15:33:12 CST 2017 - dscudiero - remove debug code
## 05-12-2017 @ 14.58.13 - ("2.0.31")  - dscudiero - misc changes to speed up
## 09-27-2017 @ 10.51.02 - ("2.0.34")  - dscudiero - Add imports
## 09-28-2017 @ 13.03.23 - ("2.0.64")  - dscudiero - Add the abilty to set defaults from the file shadows
## 09-28-2017 @ 16.03.08 - ("2.1.0")   - dscudiero - General syncing of dev to prod
## 10-02-2017 @ 13.07.54 - ("2.1.-1")  - dscudiero - General syncing of dev to prod
