#!/bin/bash
#===================================================================================================
version=1.0.17 # -- dscudiero -- Tue 10/03/2017 @ 16:12:41.81
#===================================================================================================
TrapSigs 'on'
myIncludes="RunSql2"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Take a tools script offline or display the current scripts offline"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName

if [[ -n $originalArgStr ]]; then
	for script in $originalArgStr; do
		[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
		sqlStmt="update $scriptsTable set active=\"Offline\" where name=\"$script\""
		RunSql2 $sqlStmt
		Msg3 "^$script is now online"
	done
else
	Msg3 "Current offline scripts:"
	sqlStmt="select name,showInScripts from $scriptsTable where active=\"Offline\" order by showInScripts,name"
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
## Mon Apr 11 08:42:19 CDT 2016 - dscudiero - output all offline scripts if nothing passed in
## Thu May  5 09:20:53 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:44 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Jul 27 12:41:23 CDT 2016 - dscudiero - Fix problem where it was picking up N/A scripts
## 10-03-2017 @ 16.13.44 - (1.0.17)    - dscudiero - Refactored to allow report on all offline scripts
