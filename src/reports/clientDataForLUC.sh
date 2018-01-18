#!/bin/bash
#XO NOT AUTOVERSION
version=1.0.25 # -- dscudiero -- Thu 01/18/2018 @ 15:37:56.22
originalArgStr="$*"
scriptDescription=""
TrapSigs 'on'

#= Description +===================================================================================
# Report to return data for LUC, returnes data as defined in fields below
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function parseArgs-clientDataForLUC  { # or parseArgs-local
	:
	return 0
}
function Goodbye-clientDataForLUC  { # or Goodbye-local
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}
function testMode-clientDataForLUC  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

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
RunSql2 $sqlStmt
if [[ ${#resultSet[@]} -gt 0 ]]; then
	Msg3 "${fields//,/\t}"
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
		Msg3 "${outLine:2}"
	done
else
	Warning "Did not find any contacts records meeting criteria"
fi

#===================================================================================================
## Done
#===================================================================================================
Goodbye 'quiet'

#===================================================================================================
## Check-in log
#===================================================================================================
## 11-06-2017 @ 16.43.26 - (1.0.12)    - dscudiero - Switch to new excel reader
## 11-08-2017 @ 12.22.21 - (1.0.13)    - dscudiero - Only return clients who have 'opted-in' (leepday=Y)
## 11-15-2017 @ 11.25.47 - (1.0.17)    - dscudiero - Updated to only report opted in contact records
