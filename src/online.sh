#!/bin/bash
#===================================================================================================
version=1.0.26 # -- dscudiero -- Thu 03/22/2018 @ 13:58:40.20
#===================================================================================================
TrapSigs 'on'
myIncludes="RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Bring a tools script online"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName

[[ $(Contains "$administrators" "$userName") != true ]] && Terminate "You do not have sufficient permissions to run this scrip"

if [[ -n $originalArgStr ]]; then
	for script in $originalArgStr; do
		[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
		sqlStmt="update $scriptsTable set active=\"Yes\" where name=\"$script\""
		RunSql $sqlStmt
		Msg "^$script is now online"
	done
else
	Msg "Current online scripts:"
	sqlStmt="select name,showInScripts from $scriptsTable where active=\"Yes\" order by showInScripts,name"
	RunSql $sqlStmt
	for result in ${resultSet[@]}; do
		Msg "^${result%%|*}^${result##*|}" 
	done
	Msg
fi

Goodbye
#===================================================================================================
## Check-in log
#===================================================================================================
## Thu May  5 09:21:05 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:53 CDT 2016 - dscudiero - General syncing of dev to prod
## 10-03-2017 @ 07.39.17 - (1.0.13)    - dscudiero - Add RunSql to the include list
## 10-03-2017 @ 16.14.01 - (1.0.23)    - dscudiero - Refactored to allow for report of all online scripts
## 02-02-2018 @ 10.46.41 - 1.0.24 - dscudiero - D
## 03-22-2018 @ 14:07:12 - 1.0.26 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
