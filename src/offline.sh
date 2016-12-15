#!/bin/bash
#===================================================================================================
version=1.0.10 # -- dscudiero -- 12/14/2016 @ 11:28:23.07
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName
ParseArgsStd

ignoreScripts='patcher,setEdition,newNewsItem,callPgm,testsh,WorkWith'
script=$client
if [[ $script = '' ]]; then
	Msg2 "Current offline scripts:"
	sqlStmt="select name from $scriptsTable where active=\"No\""
	RunSql 'mysql' $sqlStmt
	for result in ${resultSet[@]}; do
		[[ $(Contains ",$ignoreScripts," ",$result,") != true ]] && Msg2 "^$result"
	done
	Msg2
else
	Prompt script "Please specify the script to take offline" '*any*'

	[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
	sqlStmt="update $scriptsTable set active=\"No\" where name=\"$script\""
	RunSql 'mysql' $sqlStmt
fi

#===================================================================================================
## Check-in log
#===================================================================================================
## Mon Apr 11 08:42:19 CDT 2016 - dscudiero - output all offline scripts if nothing passed in
## Thu May  5 09:20:53 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:44 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Jul 27 12:41:23 CDT 2016 - dscudiero - Fix problem where it was picking up N/A scripts
