#!/bin/bash
#==================================================================================================
version=1.0.3 # -- dscudiero -- 12/14/2016 @ 11:27:19.39
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
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
	#==============================================================================================
	# parse script specific arguments
	#==============================================================================================
	function parseArgs-loadCimCourses {
		:
	}
	function Goodbye-loadCimCourses  {
		:
	}

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs'
VerifyContinue "You are asking to import course for:\n\tclient: $client\n\tEnv: $env"
Msg2

#==================================================================================================
## Main
#==================================================================================================
Msg2 "Importing courses into CIM ...\n"
cd $srcDir/clienttransfers/cimcourses/
if find $srcDir/clienttransfers/cimcourses/ -maxdepth 0 -empty | read
then
	Warning 0 1 "There are no files in $srcDir/clienttransfers/cimcourses/\n"
else
	cd $srcDir/web/courseleaf
	$DOIT ./courseleaf.cgi courseimportcim /courseadmin/index.html >> $tmpFile  >&1
	Msg2 "Step output can be found in $tmpFile"
fi

################################################################################
## Bye-bye
Goodbye 0
 