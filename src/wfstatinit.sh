#!/bin/bash
#===================================================================================================
version=2.0.7 # -- dscudiero -- Fri 03/23/2018 @ 17:03:20.28
#===================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Rebuild workflow stats"

#===================================================================================================
#= Reinitialize workflow stats for a site (i.e. rebuild the console status thermometer)
#===================================================================================================
# 05-28-14 -- 	dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
#===================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
GetDefaultsData $myName
ParseArgsStd $originalArgStr
Msg
Init 'getClient getEnv getDirs checkEnvs'
VerifyContinue "You are asking to reset workflow statistics for\n\tclient:$client\n\tEnv:$env ($siteDir)"

#===================================================================================================
#= Main
#===================================================================================================
Msg "Running wfstatinit & wfstatbuild...."
cd $siteDir/web/courseleaf
$DOIT ./courseleaf.cgi wfstatinit /index.html 2>&1 | xargs -I{} printf "\\t%s\\n" "{}"
$DOIT ./courseleaf.cgi -e wfstatbuild / 2>&1 | xargs -I{} printf "\\t%s\\n" "{}"

#===================================================================================================
#= Bye-bye
#===================================================================================================
Goodbye 0

#===================================================================================================
#= Check-in Log
#===================================================================================================
## Tue Aug 16 07:18:23 CDT 2016 - dscudiero - fix problem usning tgtDir when not set
## 11-01-2017 @ 16.51.03 - (2.0.5)     - dscudiero - Switch to ParseArgStd2 and Msg
## 03-23-2018 @ 15:36:27 - 2.0.6 - dscudiero - D
## 03-23-2018 @ 17:04:53 - 2.0.7 - dscudiero - Msg3 -> Msg
