#!/bin/bash
#==================================================================================================
version="2.6.86" # -- dscudiero -- Fri 05/31/2019 @ 13:22:31
#==================================================================================================
TrapSigs 'on'
myIncludes="GetCourseleafPgm PrintBanner PushPop"
Import "$standardInteractiveIncludes $myIncludes"

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

myArgs="site|siteDir|option|siteDir|;"
export myArgs="$myArgs"

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
# function wizdebug-ParseArgsStd  {
# 	myArgs+=("ribbit|ribbitDebug|switch|ribbitDebug||script|Display the wizdebug file from the ribbit folder")
# 	myArgs+=("site|siteDir|option|siteDir||script|The fully qualified site directory root")
# 	return 0
# }
function testsh-Goodbye  {
	Popd
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
Hello
helpSet='script,client,env'
SetDefaults $myName
ParseArgs $originalArgStr

if [[ -z $siteDir ]]; then
	Init 'getClient getEnv getDirs checkEnvs noPreview noPublic'
fi
dump -1 client env envs siteDir fastinit -p

#===================================================================================================
#= Main
#===================================================================================================
courseLeafDir=$(GetCourseleafPgm "$siteDir" | cut -d' ' -f2)
debugFile="$courseLeafDir/wizdebug.out"
if [[ $ribbitDebug == true ]]; then 
	Pushd "$courseLeafDir"
	cd "../ribbit"
	debugFile="$(pwd)/wizdebug.out"
fi
[[ ! -f "$debugFile" ]] && Msg && Terminate "Could not locate wizdebug.out file:\n\t$debugFile"

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
## 10-04-2017 @ 13.49.10 - (2.6.65)    - dscudiero - Tweak startup messaging
## 03-22-2018 @ 12:36:35 - 2.6.66 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-22-2018 @ 13:25:51 - 2.6.67 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:36:31 - 2.6.68 - dscudiero - D
## 11-08-2018 @ 12:02:01 - 2.6.79 - dscudiero - Add coding for fastInit
## 12-18-2018 @ 08:40:02 - 2.6.80 - dscudiero - Cosmetic/minor change/Sync
## 04-19-2019 @ 14:45:44 - 2.6.85 - dscudiero -  Switch to the C++ argument parser
