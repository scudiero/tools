#!/bin/bash
#==================================================================================================
version=1.10.3 # -- dscudiero -- 12/14/2016 @  9:09:44.57
#==================================================================================================
originalArgStr="$*"
scriptDescription="Set aliases to goto courseleaf sites"

## Copyright ©2015 David Scudiero -- all rights reserved.
#==================================================================================================
# Declare local variables and constants
#==================================================================================================

#==================================================================================================
## Set top level server aliases 
#==================================================================================================
	for server in $(echo $devServers | tr ',' ' '); do
		alias $server="cd /mnt/$server/web"
	done
	for server in $(echo $prodServers | tr ',' ' '); do
		alias $server="cd /mnt/$server"
	done

#==================================================================================================
## lookup client in sites database, set aliases
#==================================================================================================
	[[ -d $TOOLSPATH/scripts ]] && toolsDir="$TOOLSPATH/scripts"
	[[ -d $TOOLSPATH/bin ]] && toolsDir="$TOOLSPATH/bin"

	sqlStmt="select distinct name from $siteInfoTable "
	RunSql 'mysql' $sqlStmt
	if [[ ${#resultSet[@]} = 0 ]]; then 
		printf "setSiteAliases: *Error* -- No records returned from query: \n\t'$sqlStmt'\nNo aliases set\n"; 
	else
		for result in "${resultSet[@]}"; do
			alias $result=". $toolsDir/goto $result \$@"
		done
	fi

#==================================================================================================
## Bye-bye
#==================================================================================================
	cd $HOME
	return 0
## Wed Apr 27 15:51:58 CDT 2016 - dscudiero - Switch to use RunSql
