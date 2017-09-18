#!/bin/bash
#==================================================================================================
version=2.6.64 # -- dscudiero -- Thu 09/14/2017 @ 16:50:51.25
#==================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue' #includes="$includes xxx"
includes="$includes GetCourseleafPgm PrintBanner"
Import "$includes"

originalArgStr="$*"
scriptDescription="Monitor the log messages (courseleaf/wizdebug.out) for a CourseLeaf site"

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
unset client env srcEnv tgtEnv srcDir tgtDir siteDir pvtDir devDir testDir currDir previewDir publicDir

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd
Hello

Init 'getClient getEnv getDirs checkEnvs noPreview noPublic'

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
## 06-09-2017 @ 08.19.24 - (2.6.60)    - dscudiero - Fix problem clearing the env variable
## 06-12-2017 @ 07.18.27 - (2.6.61)    - dscudiero - General syncing of dev to prod
## 09-11-2017 @ 15.52.47 - (2.6.62)    - dscudiero - x
