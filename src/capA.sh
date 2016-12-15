#!/bin/bash
#==================================================================================================
version=1.2.1 # -- dscudiero -- 12/14/2016 @ 11:20:52.13
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Force approce courseleaf pages"

#==================================================================================================
## Cap A an site or subdirectory of a site
#==================================================================================================
## 05-28-14 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello
Init 'courseleaf' 'noCims'

#==================================================================================================
# Gather/verify data from the user
#==================================================================================================
Prompt capAdir "What directory do you wish to approve (enter '/' for all pages)?"; capAdir=$(Lower $capAdir)
if [[ $DEBUG = 1 ]]; then dump client env capAdir; fi

## Make sure the user really wants to do this
VerifyContinue "You are asking to 'Cap-A' the '$capAdir' directory on down in the $env site for $client\
				\n\tsite = $srcDir\n\tstarting dir = $srcDir/web$capAdir...\n"

#==================================================================================================
## Main
#==================================================================================================
cd $srcDir/web/courseleaf
$DOIT ./courseleaf.cgi -A $capAdir

#==================================================================================================
## Bye-bye
Goodbye 0