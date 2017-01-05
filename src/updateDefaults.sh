#!/bin/bash
#==================================================================================================
version=2.0.21 # -- dscudiero -- 01/05/2017 @ 14:22:04.74
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
Import "$includes"
originalArgStr="$*"
scriptDescription="Sync warehouse defaults table"

#==================================================================================================
#
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 06-17-14 -- 	dgs - Initial coding
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

#==================================================================================================
## Main
#==================================================================================================
## Load default settings
GetDefaultsData 'buildSiteInfoTable'
ignoreList="${ignoreList##*ignoreShares:}" ; ignoreList="${ignoreList%% *}"

## DEV servers
	unset newServers
	for server in $(ls /mnt | grep '^dev' ); do
		[[ $(Contains ",$ignoreList," ",$server,") == true ]] && continue
		ProtectedCall "cd /mnt/$server > /dev/null 2>&1"
		[[ $(pwd) != /mnt/$server ]] && continue
		newServers="$newServers,$server"
	done
	newServers=${newServers:1}
	Verbose "devServers = '$newServers'"
	## Check to see if record exists
		sqlStmt="select count(*) from defaults where name=\"devServers\" and host=\"$hostName\" and os=\"linux\""
		RunSql 'mysql' $sqlStmt; count=${resultSet[0]}
		if [[ $count -eq 0 ]]; then
			sqlStmt="insert into defaults values(NULL,\"devServers\",\"$newServers\",\"linux\",\"$hostName\",Now(),\"$userName\",NULL,NULL)"
		else
			sqlStmt="update defaults set value=\"$newServers\",updatedOn=Now(),updatedBy=\"$userName\" where name=\"devServers\" and host=\"$hostName\" and os=\"linux\""
		fi
		dump -1 -t sqlStmt
		RunSql 'mysql' $sqlStmt

## PROD servers
	unset newServers
	unset newServers
	for server in $(ls /mnt | grep -v '^dev' | grep -v '^auth'); do
		[[ $(Contains ",$ignoreList," ",$server,") == true ]] && continue
		ProtectedCall "cd /mnt/$server > /dev/null 2>&1"
		[[ $(pwd) != /mnt/$server ]] && continue
		newServers="$newServers,$server"
	done
	newServers=${newServers:1}
	Verbose "prodServers = '$newServers'"
	## Check to see if record exists
		sqlStmt="select count(*) from defaults where name=\"prodServers\" and host=\"$hostName\" and os=\"linux\""
		RunSql 'mysql' $sqlStmt; count=${resultSet[0]}
		if [[ $count -eq 0 ]]; then
			sqlStmt="insert into defaults values(NULL,\"prodServers\",\"$newServers\",\"linux\",\"$hostName\",Now(),\"$userName\",NULL,NULL)"
		else
			sqlStmt="update defaults set value=\"$newServers\",updatedOn=Now(),updatedBy=\"$userName\" where name=\"prodServers\" and host=\"$hostName\" and os=\"linux\""
		fi
		dump -1 -t sqlStmt
		RunSql 'mysql' $sqlStmt


## Update rhel version.
	rhel="$(cat /etc/redhat-release | cut -d" " -f3 | cut -d '.' -f1)"
	[[ $(IsNumeric ${rhel:0:1}) != true ]] && rhel=$(cat /etc/redhat-release | cut -d" " -f4 | cut -d '.' -f1)
	rhel='rhel'$rhel
	dump -1 rhel
	sqlStmt="update defaults set value=\"$rhel\" where name=\"rhel\" and host=\"$hostName\" and os=\"linux\""
	RunSql 'mysql' $sqlStmt

## Default CL version from the 'release' directory in the skeleton
	unset defaultClVer
	if [[ -r $skeletonRoot/release/web/courseleaf/clver.txt ]]; then
		defaultClVer="$(cat $skeletonRoot/release/web/courseleaf/clver.txt)"
		dump -1 defaultClVer
		sqlStmt="update defaults set value=\"$defaultClVer\" where name=\"defaultClVer\""
		RunSql 'mysql' $sqlStmt
	else
		Msg2 "Could not read file: '$skeletonRoot/release/web/courseleaf/clver.txt'"
	fi

#==================================================================================================
## Update servers in the default.ini file

Goodbye 0;
#==================================================================================================
# Change Log
#==================================================================================================
## Fri Mar 18 07:00:52 CDT 2016 - dscudiero - Additional filtering of sites using the ignoreList from buildsiteinfotable
## Fri Mar 18 07:01:41 CDT 2016 - dscudiero - General syncing of dev to prod
## Thu Mar 31 09:06:31 CDT 2016 - dscudiero - Turn off unnecessary messaging
## Wed Apr 20 10:14:47 CDT 2016 - dscudiero - Rename file
## Wed Apr 27 15:52:11 CDT 2016 - dscudiero - Switch to use RunSql
## Mon Jul 18 14:07:59 EDT 2016 - dscudiero - Fix problem if the default vaiable was not already in the defaults table, use insert
## Tue Sep 20 07:16:50 CDT 2016 - dscudiero - Fix problem if we do not have prmissions to cd to a directory
## Thu Oct  6 16:40:23 CDT 2016 - dscudiero - Set dbAcc level to Update for db writes
## Thu Oct  6 16:59:41 CDT 2016 - dscudiero - General syncing of dev to prod
## Fri Oct  7 08:01:02 CDT 2016 - dscudiero - Take out the dbAcc switching logic, moved to framework RunSql
## Thu Jan  5 14:50:53 CST 2017 - dscudiero - Fix problem setting the shares ignore list
