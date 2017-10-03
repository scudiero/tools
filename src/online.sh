#!/bin/bash
#===================================================================================================
version=1.0.23 # -- dscudiero -- Tue 10/03/2017 @ 16:12:52.56
#===================================================================================================
TrapSigs 'on'
myIncludes="RunSql2"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Bring a tools script online"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName

if [[ -n $originalArgStr ]]; then
	for script in $originalArgStr; do
		[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
		sqlStmt="update $scriptsTable set active=\"Yes\" where name=\"$script\""
		RunSql2 $sqlStmt
		Msg3 "^$script is now online"
	done
else
	Msg3 "Current online scripts:"
	sqlStmt="select name,showInScripts from $scriptsTable where active=\"Yes\" order by showInScripts,name"
	RunSql2 $sqlStmt
	for result in ${resultSet[@]}; do
		Msg3 "^${result%%|*}^${result##*|}" 
	done
	Msg3
fi

Goodbye
#===================================================================================================
## Check-in log
#===================================================================================================
## Thu May  5 09:21:05 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:53 CDT 2016 - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 07.39.17 - (1.0.13)    - dscudiero - Add RunSql2 to the include list
## 10-03-2017 @ 16.14.01 - (1.0.23)    - dscudiero - Refactored to allow for report of all online scripts
