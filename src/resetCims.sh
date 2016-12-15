#!/bin/bash
#====================================================================================================
version=1.0.2 # -- dscudiero -- 12/14/2016 @ 11:29:53.02
#====================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription=""

#====================================================================================================
# Reset CIM instances
#====================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 04-15-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#====================================================================================================

#====================================================================================================
# Declare local variables and constants
#====================================================================================================

#====================================================================================================
# Standard arg parsing and initialization
#====================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'getClient getEnv getDirs checkEnvs getCims'
VerifyContinue "You are asking to reset CIMS for\n\tclient:$client\n\tEnv: $env\n\tCIMSs: $cimStr"

#====================================================================================================
## Main
#====================================================================================================
cd $srcDir/web/courseleaf
for cim in $(echo $cimStr | tr ',' ' '); do
	Msg2 "Processing $cim"
	Msg2 "^^Cleaning status tables..."
	cimType=${cim%%admin}
	table="$cimType"'_status'
	$DOIT sqlite3 $srcDir/db/cimcourses.sqlite "delete from $table"
	$DOIT sqlite3 $srcDir/db/cimcourses.sqlite 'delete from xreffam'
	$DOIT sqlite3 $srcDir/db/cimcourses.sqlite 'delete from xreffammember'

	Msg2 "^^Removing existing proposal dirs/files..."
	cd $srcDir/web/$cim
	dirs=$(find -maxdepth 1 -type d -printf "%f ")
	for dir in $dirs; do
		if [[ $dir == '.' ]]; then continue; fi
		$DOIT rm -rf $dir
	done
	Msg2 "^^Completed"
done

Msg2 "Rebuilding the pages database..."
cd $srcDir/web/courseleaf
if [[ $DOIT != 'echo' ]]; then
	./courseleaf.cgi -p > /dev/null 2>&1
fi
Msg2 "Completed"

#====================================================================================================
## Bye-bye
#====================================================================================================
Goodbye 0 "$client/$env"
