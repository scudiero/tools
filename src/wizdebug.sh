#!/bin/bash
#==================================================================================================
version=2.6.59 # -- dscudiero -- Thu 06/08/2017 @ 16:24:40.71
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' 
imports="$imports GetCourseleafPgm"
Import "$imports"
originalArgStr="$*"
scriptDescription="Tail a site wizdebug.out file"

#==================================================================================================
## Tail the wizdebug.out file for a site
#==================================================================================================
#==================================================================================================
## Copyright ©2014 David Scudiero -- all rights reserved.
## 06-01-15 -- 	dgs - Refactored to use standard tools
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
unset client

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd
Hello

Init 'Clear getClient getEnv getDirs checkEnvs noPreview noPublic'

#===================================================================================================
#= Main
#===================================================================================================
courseLeafDir=$(GetCourseleafPgm "$siteDir" | cut -d' ' -f2)
debugFile="$courseLeafDir/wizdebug.out"
[[ ! -f "$debugFile" ]] && Msg2 && TerminateMsg "Could not locate wizdebug.out file:\n\t$debugFile"

[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
echo -e "$colorKey"
PrintBanner "tail $debugFile, Ctrl-C to stop"
echo -e "$colorDefault"

tail -n 15 -f $debugFile

#===================================================================================================
## Bye-bye
#===================================================================================================
Goodbye 0

#===================================================================================================
## Check-in log
#===================================================================================================
# 11-25-2015 -- dscudiero -- sync (2.5)
# 11-25-2015 -- dscudiero -- sync (2.6)
## Thu Apr 14 13:16:19 CDT 2016 - dscudiero - Tweak message colors
## Thu Apr 21 08:32:25 CDT 2016 - dscudiero - Use GetCourseleafPgm to locate the wizdebug file location
## Thu Apr 21 08:56:26 CDT 2016 - dscudiero - Use echo command instead of Msg
## Thu Sep 29 12:54:34 CDT 2016 - dscudiero - Do not clear screen if TERM=dumb
## 06-08-2017 @ 16.28.01 - (2.6.59)    - dscudiero - Added clearing of data on start
