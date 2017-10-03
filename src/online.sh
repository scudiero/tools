#!/bin/bash
#===================================================================================================
version=1.0.13 # -- dscudiero -- Tue 10/03/2017 @  7:36:39.52
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
## 10-03-2017 @ 07.39.17 - (1.0.13)    - dscudiero - Add RunSql2 to the include list
