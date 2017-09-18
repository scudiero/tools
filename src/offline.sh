#!/bin/bash
#===================================================================================================
version=1.0.12 # -- dscudiero -- Thu 09/14/2017 @ 12:24:59.05
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Take a tools script offline or display the current scripts offline"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName
ParseArgsStd

ignoreScripts='patcher,setEdition,newNewsItem,callPgm,testsh,WorkWith'
script=$client
if [[ $script = '' ]]; then
	Msg2 "Current offline scripts:"
	sqlStmt="select name from $scriptsTable where active=\"Offline\""
	RunSql2 $sqlStmt
	for result in ${resultSet[@]}; do
		[[ $(Contains ",$ignoreScripts," ",$result,") != true ]] && Msg2 "^$result"
	done
	Msg2
else
	Prompt script "Please specify the script to take offline" '*any*'

	[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
	sqlStmt="update $scriptsTable set active=\"Offline\" where name=\"$script\""
	RunSql2 $sqlStmt
fi

#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Apr 11 08:42:19 CDT 2016 - dscudiero - output all offline scripts if nothing passed in
## Thu May  5 09:20:53 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:44 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Jul 27 12:41:23 CDT 2016 - dscudiero - Fix problem where it was picking up N/A scripts
