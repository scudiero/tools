#!/bin/bash
#===================================================================================================
version=1.0.4 # -- dscudiero -- 12/14/2016 @ 11:28:31.30
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

script=$client
Prompt script "Please specify the script to take online" '*any*'

[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
sqlStmt="update $scriptsTable set active=\"Yes\" where name=\"$script\""
RunSql 'mysql' $sqlStmt
#===================================================================================================
## Check-in log
#===================================================================================================
## Thu May  5 09:21:05 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:53 CDT 2016 - dscudiero - General syncing of dev to prod
