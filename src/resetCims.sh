#!/bin/bash
#====================================================================================================
version=1.0.5 # -- dscudiero -- Fri 09/08/2017 @ 12:16:56.80
#====================================================================================================
TrapSigs 'on'
includes='Msg2 Dump GetDefaultsData ParseArgsStd Hello DbLog Init Goodbye VerifyContinue'
Import "$includes"

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
helpSet='client,env,cim' # can also include any of {env,src,tgt,prod,cim,cat,clss}, 'script' and 'common' automatically addeed
scriptHelpDesc+=("This script can be used to clean one or more CIM instances in a client site, essentially after cleaning the CIM instance will look brand new.")
scriptHelpDesc+=("The actions performed are:")
scriptHelpDesc+=("^1) Empty the following tables in each CIM instance: <cimInstance>_status, xreffam, xreffamember")
scriptHelpDesc+=("^2) Deletes all directories under the CIM instance directory (i.e. the proposals)")
scriptHelpDesc+=("^3) Rebuilds the pages database")
scriptHelpDesc+=("\nTarget site data files potentially modified:")
scriptHelpDesc+=("^As above")


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
