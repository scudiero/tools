#!/bin/bash
#==================================================================================================
version=2.0.5 # -- dscudiero -- 01/12/2017 @ 12:58:50.43
#==================================================================================================
scriptDescription="Build dos cmd file setting default values"
TrapSigs 'on'

#==================================================================================================
# Write out a .cmd file that can be called by a dos command
# file sets various defaults data
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 06-28-15 -- 	dgs - Initial coding
#==================================================================================================
# Declare local variables and constants
#==================================================================================================
noLog=true; noDbLog=true;

#==================================================================================================
## Main
#==================================================================================================
## DEV servers
	unset devServers
	sqlStmt="select value from defaults where name=\"devServers\" "
	RunSql2 $sqlStmt
	for results in "${resultSet[@]}"; do
		devServers=$devServers,$results
	done
	devServers=${devServers:1}
## PROD servers
	unset prodServers
	sqlStmt="select value from defaults where name=\"prodServers\" "
	RunSql2 $sqlStmt
	for results in "${resultSet[@]}"; do
		prodServers=$prodServers,$results
	done
	prodServers=${prodServers:1}

## Write out the file
	chmod 750 $TOOLSPATH/defaultsData.cmd
	echo > $TOOLSPATH/defaultsData.cmd
	echo "set devServers=$devServers" >> $TOOLSPATH/defaultsData.cmd
	echo "set prodServers=$prodServers" >> $TOOLSPATH/defaultsData.cmd
	echo "set envs=$courseleafEnvs" >> $TOOLSPATH/defaultsData.cmd



#==================================================================================================
Goodbye
## Thu Apr 14 16:05:31 CDT 2016 - dscudiero - General syncing of dev to prod
## Wed Apr 27 16:18:18 CDT 2016 - dscudiero - Switch to use RunSql
