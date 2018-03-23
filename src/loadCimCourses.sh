#!/bin/bash
#==================================================================================================
version=1.0.5 # -- dscudiero -- Fri 03/23/2018 @ 14:34:33.64
#==================================================================================================
TrapSigs 'on'
myIncludes="Msg ProtectedCall StringFunctions RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Load CIM courses"

#==================================================================================================
# Load cim courses
#==================================================================================================
## Copyright ©2014 David Scudiero -- all rights reserved.
## 06-17-15 -- 	dgs - Initial coding
#==================================================================================================
#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd $originalArgStr
Hello
Init 'getClient getEnv getDirs checkEnvs'
VerifyContinue "You are asking to import course for:\n\tclient: $client\n\tEnv: $env"
Msg

#==================================================================================================
## Main
#==================================================================================================
Msg "Importing courses into CIM ...\n"
cd $srcDir/clienttransfers/cimcourses/
if find $srcDir/clienttransfers/cimcourses/ -maxdepth 0 -empty | read
then
	Warning 0 1 "There are no files in $srcDir/clienttransfers/cimcourses/\n"
else
	cd $srcDir/web/courseleaf
	$DOIT ./courseleaf.cgi courseimportcim /courseadmin/index.html >> $tmpFile  >&1
	Msg "Step output can be found in $tmpFile"
fi

################################################################################
## Bye-bye
Goodbye 0
 ## 03-23-2018 @ 15:35:04 - 1.0.5 - dscudiero - D
