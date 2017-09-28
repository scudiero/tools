#!/bin/bash
#==================================================================================================
version=2.0.35 # -- dscudiero -- Thu 09/28/2017 @ 10:52:09.55
#==================================================================================================
TrapSigs 'on'
myIncludes=""
Import "$standardIncludes $myIncludes"
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
## Maine
#==================================================================================================
## Load default settings
GetDefaultsData #'buildSiteInfoTable'
ignoreList="${ignoreList##*ignoreShares:}" ; ignoreList="${ignoreList%% *}"

mode="$1" ; shift || true

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
		RunSql2 $sqlStmt; count=${resultSet[0]}
		if [[ $count -eq 0 ]]; then
			sqlStmt="insert into defaults values(NULL,\"devServers\",\"$newServers\",\"linux\",\"$hostName\",Now(),\"$userName\",NULL,NULL)"
		else
			sqlStmt="update defaults set value=\"$newServers\",updatedOn=Now(),updatedBy=\"$userName\" where name=\"devServers\" and host=\"$hostName\" and os=\"linux\""
		fi
		dump -1 -t sqlStmt
		RunSql2 $sqlStmt

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
		RunSql2 $sqlStmt; count=${resultSet[0]}
		if [[ $count -eq 0 ]]; then
			sqlStmt="insert into defaults values(NULL,\"prodServers\",\"$newServers\",\"linux\",\"$hostName\",Now(),\"$userName\",NULL,NULL)"
		else
			sqlStmt="update defaults set value=\"$newServers\",updatedOn=Now(),updatedBy=\"$userName\" where name=\"prodServers\" and host=\"$hostName\" and os=\"linux\""
		fi
		dump -1 -t sqlStmt
		RunSql2 $sqlStmt

## Update rhel version.
	rhel="$(cat /etc/redhat-release | cut -d" " -f3 | cut -d '.' -f1)"
	[[ $(IsNumeric ${rhel:0:1}) != true ]] && rhel=$(cat /etc/redhat-release | cut -d" " -f4 | cut -d '.' -f1)
	rhel='rhel'$rhel
	dump -1 rhel
	sqlStmt="update defaults set value=\"$rhel\" where name=\"rhel\" and host=\"$hostName\" and os=\"linux\""
	RunSql2 $sqlStmt

## Default CL version from the 'release' directory in the skeleton
	unset defaultClVer
	if [[ -r $skeletonRoot/release/web/courseleaf/clver.txt ]]; then
		defaultClVer="$(cat $skeletonRoot/release/web/courseleaf/clver.txt)"
		dump -1 defaultClVer
		sqlStmt="update defaults set value=\"$defaultClVer\" where name=\"defaultClVer\""
		RunSql2 $sqlStmt
	else
		Warning "Could not read file: '$skeletonRoot/release/web/courseleaf/clver.txt'"
	fi

## Write out the defaults files
	if [[ $mode == 'all' || $mode == 'common' ]]; then
		defaultsFile="$TOOLSDEFAULTSPATH/common"
		sqlStmt="select name,value from defaults where (os is NUll or os in (\"linux\")) and status=\"A\" order by name"
		RunSql2 $sqlStmt
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED FROM THE DEFAULTS TABLE IN THE DATA WAREHOUSE" > "$defaultsFile"
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				result="${resultSet[$ii]}"
				name=${result%%|*}
				value=${result##*|}
				echo "$name=\"$value\"" >> "$defaultsFile"
			done
			chgrp 'leepfrog' "$defaultsFile"
			chmod 750 "$defaultsFile"
		else
			Warning "Could not retrieve defaults data for 'common' from the data warehouse\n$sqlStmt"
		fi

		## Get script defaults data
		fields="name,scriptArgs,ignoreList,allowList,emailAddrs,scriptData1,scriptData2,scriptData3,scriptData4,scriptData5,setSemaphore,waitOn"
		IFS=',' read -r -a fieldsArray <<< "$fields"
		where="where active not in (\"No\",\"Old\")"
		sqlStmt="select $fields from $scriptInfoTable $where order by name"
		RunSql2 $sqlStmt
		[[ ${#resultSet[@]} -gt 0 ]] && rm -f "$defaultsFile >& /dev/null"
		if [[ ${#resultSet[@]} -gt 0 ]]; then
			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
				result="${resultSet[$ii]}"
				name=${result%%|*}
				[[ ${name:0:1} == '_' ]] && continue
				defaultsFile="$TOOLSDEFAULTSPATH/$name"
				echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED FROM THE DEFAULTS TABLE IN THE DATA WAREHOUSE" > "$defaultsFile"
				for ((ij=2; ij<${#fieldsArray[@]}; ij++)); do
					field=${fieldsArray[$ij]}
					value="$(cut -d'|' -f$ij <<< "$result")"
					[[ $value == 'NULL' ]] && echo "unset $field" >> "$defaultsFile" || echo "$field=\"$(cut -d'|' -f$ij <<< "$result")\"" >> "$defaultsFile"
				done
			done
			chgrp 'leepfrog' "$defaultsFile"
			chmod 750 "$defaultsFile"
		else
			Warning "Could not retrieve defaults data for 'scripts' from the data warehouse\n$sqlStmt"
		fi
	fi

	defaultsFile="$TOOLSDEFAULTSPATH/$hostName"
	sqlStmt="select name,value from defaults where (os is NUll or os in (\"linux\")) and host=\"$hostName\" and status=\"A\" order by name"
	RunSql2 $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED FROM THE DEFAULTS TABLE IN THE DATA WAREHOUSE" > "$defaultsFile"
		for ((ii=0; ii<${#resultSet[@]}; ii++)); do
			result="${resultSet[$ii]}"
			name=${result%%|*}
			value=${result##*|}
			echo "$name=\"$value\"" >> "$defaultsFile"
		done
		chgrp 'leepfrog' "$defaultsFile"
		chmod 750 "$defaultsFile"
	else
		Warning "Could not retrieve defaults data for '$hostName' from the data warehouse\n$sqlStmt"
	fi

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
## 09-19-2017 @ 06.56.27 - (2.0.23)    - dscudiero - redo imports
## 09-28-2017 @ 08.50.05 - (2.0.27)    - dscudiero - Added updating the defaults files
## 09-28-2017 @ 09.16.34 - (2.0.28)    - dscudiero - General syncing of dev to prod
## 09-28-2017 @ 09.23.24 - (2.0.30)    - dscudiero - Add warning messages if we cannot get data from the warehouse
## 09-28-2017 @ 10.44.11 - (2.0.32)    - dscudiero - Add scripts defaults file generation
## 09-28-2017 @ 10.45.34 - (2.0.33)    - dscudiero - tweak messaging
## 09-28-2017 @ 10.48.13 - (2.0.34)    - dscudiero - Change group and permissions on the defaults files
## 09-28-2017 @ 10.50.44 - dscudiero - General syncing of dev to prod
## 09-28-2017 @ 10.52.36 - (2.0.35)    - dscudiero - General syncing of dev to prod
