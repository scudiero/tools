#!/bin/bash
#===================================================================================================
version=1.0.10 # -- dscudiero -- Thu 09/14/2017 @ 12:42:23.27
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Bring a tools script online"

#===================================================================================================
## turn a script offline -- i.e. create an .offline file
#===================================================================================================
GetDefaultsData $myName
ParseArgsStd

script=$client
Prompt script "Please specify the script to take online" '*any*'

[[ ${script: (-3)} == '.sh' ]] && script="$(cut -d'.' -f1 <<< $script)"
sqlStmt="update $scriptsTable set active=\"Yes\" where name=\"$script\""
RunSql2 $sqlStmt
#===================================================================================================
## Check-in log
#===================================================================================================
## Thu May  5 09:21:05 CDT 2016 - dscudiero - Switch to set offline in the database
## Fri Jul 15 13:22:53 CDT 2016 - dscudiero - General syncing of dev to prod
