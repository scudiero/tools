#!/bin/bash
#===================================================================================================
version=2.0.4 # -- dscudiero -- 12/14/2016 @ 11:32:07.80
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
GetDefaultsData $myName
ParseArgsStd
Hello
Msg2
Init 'getClient getEnv getDirs checkEnvs'
VerifyContinue "You are asking to reset workflow statistics for\n\tclient:$client\n\tEnv:$env ($siteDir)"

#===================================================================================================
#= Main
#===================================================================================================
Msg2 "Running wfstatinit & wfstatbuild...."
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
