#!/bin/bash
#XO NOT AUTOVERSION
version=1.0.29 # -- dscudiero -- Thu 03/22/2018 @ 13:58:59.09
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Report to return data for LUC, returnes data as defined in fields below
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData -f $myName
ParseArgsStd2 $originalArgStr

#==================================================================================================
## MAIN
#==================================================================================================
fields="name,longname,primarycontact,salesRep,catSup,cimSup,catCsm,cimCsm,clssCsm"
sqlStmt="select $fields from $clientInfoTable where recordstatus=\"A\" order by name"
RunSql $sqlStmt
if [[ ${#resultSet[@]} -gt 0 ]]; then
	Msg "${fields//,/\t}"
	for result in "${resultSet[@]}"; do
		## Escape single and double quotes
		result="${result//\'/''}"; result="${result//\"/""}"; result="${result//NULL/ }"
		fieldCntr=1
		unset outLine
		for field in $(tr ',' ' ' <<< $fields); do
			eval unset $field
			eval $field=\"$(cut -d'|' -f$fieldCntr <<< "$result")\"
			outLine="$outLine\t${!field}"
			((fieldCntr += 1))
		done
		Msg "${outLine:2}"
	done
else
	Warning "Did not find any contacts records meeting criteria"
fi

#===================================================================================================
## Done
#===================================================================================================
secondaryMessagesOnly=true
Goodbye 'quiet'

#===================================================================================================
## Check-in log
#===================================================================================================
## 11-06-2017 @ 16.43.26 - (1.0.12)    - dscudiero - Switch to new excel reader
## 11-08-2017 @ 12.22.21 - (1.0.13)    - dscudiero - Only return clients who have 'opted-in' (leepday=Y)
## 11-15-2017 @ 11.25.47 - (1.0.17)    - dscudiero - Updated to only report opted in contact records
## 03-22-2018 @ 14:07:27 - 1.0.29 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
