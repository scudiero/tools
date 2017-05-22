#!/bin/bash
#==================================================================================================
version=2.0.7 # -- dscudiero -- Mon 05/22/2017 @  8:27:23.17
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Update CIM status"

#==================================================================================================
# Update CIM status data on all cim instances -- ask user which ones to refresh.
# Runs ./courseleaf.cgi rebuildstatus
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 01-30-14 -- 	dgs - Initial coding
# 01-21-15	--	dgs - Switch to bash
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================
#
#==================================================================================================
# Declare variables and constants, bring in includes file with subs
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs getCims'
VerifyContinue "You are asking to reset workflow statistics for\n\tclient:$client\n\tEnv: $env\n\tCIMs: $cimStr"

#==================================================================================================
## Main
#==================================================================================================
cd $srcDir/web/courseleaf
for cim in $(echo $cimStr | tr ',' ' '); do
	Msg2 "Processing $cim"
	$DOIT ./courseleaf.cgi rebuildstatus /$cim 2>&1 | Indent | sed -e 's/\<br\>//g'
done

#===================================================================================================
## Bye-bye
##==================================================================================================
Goodbye 0 'alert'

#===================================================================================================
## Check-in log
##==================================================================================================
## 05-22-2017 @ 08.18.26 - (2.0.4)     - dscudiero - switch Msg to Msg2
## 05-22-2017 @ 08.23.29 - (2.0.6)     - dscudiero - General syncing of dev to prod
## 05-22-2017 @ 08.28.27 - (2.0.7)     - dscudiero - General syncing of dev to prod
