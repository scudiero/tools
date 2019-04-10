#!/bin/bash
#==================================================================================================
version="2.1.19" # -- dscudiero -- Wed 04/10/2019 @ 10:41:49
#==================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall"
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
ParseArgsStd $originalArgStr
Hello

#==================================================================================================
## Main
#==================================================================================================
ignoreList="${ignoreList##*ignoreShares:}" ; ignoreList="${ignoreList%% *}"
mode="$client"

Verbose 1 "mode = '$mode'"

if [[ -z $mode || $mode == 'servers' ]]; then
	Verbose 1 "Updating servers data"
	## DEV servers
		unset newServers
		for server in $(ls /mnt | grep '^dev' | grep -v '\-test$'); do
			[[ $(Contains ",$ignoreList," ",$server,") == true ]] || [[ ! -r /mnt/$server ]] || [[ -z "$(ls -A /mnt/$server)" ]] && continue
			newServers="$newServers,$server"
		done
		newServers=${newServers:1}
		Verbose 1 "devServers = '$newServers'"
		## Check to see if record exists
			sqlStmt="select count(*) from defaults where name=\"devServers\" and host=\"$hostName\" and os=\"linux\""
			RunSql $sqlStmt; count=${resultSet[0]}
			if [[ $count -eq 0 ]]; then
				sqlStmt="insert into defaults values(NULL,\"devServers\",\"$newServers\",\"linux\",\"$hostName\",Now(),\"$userName\",NULL,NULL)"
			else
				sqlStmt="update defaults set value=\"$newServers\",updatedOn=Now(),updatedBy=\"$userName\" where name=\"devServers\" and host=\"$hostName\" and os=\"linux\""
			fi
			dump 1 -t sqlStmt
			RunSql $sqlStmt

	## PROD servers
		unset newServers
		for server in $(ls /mnt | grep -v '^dev' | grep -v '^auth' | grep -v '\-test$'); do
			[[ $(Contains ",$ignoreList," ",$server,") == true ]] || [[ ! -r /mnt/$server ]] || [[ -z "$(ls -A /mnt/$server)" ]] && continue
			newServers="$newServers,$server"
		done
		newServers=${newServers:1}
		Verbose 1 "prod newServers = '$newServers'"
		## Check to see if record exists
			sqlStmt="select count(*) from defaults where name=\"prodServers\" and host=\"$hostName\" and os=\"linux\""
			RunSql $sqlStmt; count=${resultSet[0]}
			if [[ $count -eq 0 ]]; then
				sqlStmt="insert into defaults values(NULL,\"prodServers\",\"$newServers\",\"linux\",\"$hostName\",Now(),\"$userName\",NULL,NULL)"
			else
				sqlStmt="update defaults set value=\"$newServers\",updatedOn=Now(),updatedBy=\"$userName\" where name=\"prodServers\" and host=\"$hostName\" and os=\"linux\""
			fi
			dump 1 -t sqlStmt
			RunSql $sqlStmt
fi

if [[ -z $mode || $mode == 'versions' ]]; then
	Verbose 1 "Updating versions data"
	## Update rhel version.
		rhel="$(cat /etc/redhat-release | cut -d" " -f3 | cut -d '.' -f1)"
		[[ $(IsNumeric ${rhel:0:1}) != true ]] && rhel=$(cat /etc/redhat-release | cut -d" " -f4 | cut -d '.' -f1)
		rhel='rhel'$rhel
		dump 1 rhel
		sqlStmt="update defaults set value=\"$rhel\" where name=\"rhel\" and host=\"$hostName\" and os=\"linux\""
		RunSql $sqlStmt
		Verbose 1 "rhel = '$rhel'"

	## Default CL version from the 'release' directory in the skeleton
		unset defaultClVer
		if [[ -r $skeletonRoot/release/web/courseleaf/clver.txt ]]; then
			defaultClVer="$(cat $skeletonRoot/release/web/courseleaf/clver.txt)"
			dump 1 defaultClVer
			sqlStmt="update defaults set value=\"$defaultClVer\" where name=\"defaultClVer\""
			RunSql $sqlStmt
		else
			Warning "Could not read file: '$skeletonRoot/release/web/courseleaf/clver.txt'"
		fi
		Verbose 1 "defaultClVer = '$defaultClVer'"
fi

# if [[ -z $mode || $mode == 'defaults' ]]; then
# 	Verbose 1 "Updating defaults data"
# 	#==================================================================================================
# 	## Write out the defaults files
# 	#==================================================================================================
# 	## Common tools defaults data
# 		Verbose 1 "Updating common defaults files"
# 		defaultsFile="$TOOLSDEFAULTSPATH/common"
# 		Verbose 1 "\ndefaultsFile = '$defaultsFile'"
# 		sqlStmt="select name,value from defaults where (os is NUll or os in (\"linux\")) and status=\"A\" order by name"
# 		RunSql $sqlStmt
# 		if [[ ${#resultSet[@]} -gt 0 ]]; then
# 			[[ -f ${defaultsFile}.bak ]] && mv -f "$defaultsFile" "${defaultsFile}.bak"
# 			echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE DEFAULTS TABLE IN THE DATA WAREHOUSE" > "$defaultsFile"
# 			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
# 				result="${resultSet[$ii]}"
# 				name=${result%%|*}
# 				value=${result##*|}
# 				echo "$name=\"$value\"" >> "$defaultsFile"
# 			done
# 			chgrp 'leepfrog' "$defaultsFile"
# 			chmod 640 "$defaultsFile"
# 		else
# 			Warning "Could not retrieve defaults data for 'common' from the data warehouse\n\tsqlStmt = >$sqlStmt<"
# 		fi

# 	## Script defaults data
# 		Verbose 1 "Updating script defaults files"
# 		fields="name,ignoreList,allowList,emailAddrs,scriptData1,scriptData2,scriptData3,scriptData4,scriptData5,setSemaphore,waitOn"
# 		IFS=',' read -r -a fieldsArray <<< "$fields"
# 		where="where active not in (\"No\",\"Old\")"
# 		sqlStmt="select $fields from scripts $where order by name"
# 		RunSql $sqlStmt
# 		[[ ${#resultSet[@]} -gt 0 ]] && rm -f "$defaultsFile >& /dev/null"
# 		if [[ ${#resultSet[@]} -gt 0 ]]; then
# 			for ((ii=0; ii<${#resultSet[@]}; ii++)); do
# 				unset result
# 				result="${resultSet[$ii]}"
# 				name=${result%%|*}
# 				[[ ${name:0:1} == '_' ]] && continue
# 				defaultsFile="$TOOLSDEFAULTSPATH/$name"
# 				[[ -f ${defaultsFile}.bak ]] && mv -f "$defaultsFile" "${defaultsFile}.bak"
# 				Verbose 1 "defaultsFile = '$defaultsFile'"
# 				echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE DEFAULTS TABLE IN THE DATA WAREHOUSE" > "$defaultsFile"
# 				fieldCntr=1
# 				for ((ij=1; ij<${#fieldsArray[@]}; ij++)); do
# 					field=${fieldsArray[$ij]}
# 					(( fieldCntr++ ))
# 					value="$(cut -d'|' -f$fieldCntr <<< "$result")"
# 					[[ $value == 'NULL' || $value == '' ]] && echo "unset $field" >> "$defaultsFile" || echo "$field=\"$value\"" >> "$defaultsFile"
# 				done
# 			done
# 			chgrp 'leepfrog' "$defaultsFile"
# 			chmod 640 "$defaultsFile"
# 		else
# 			Warning "Could not retrieve defaults data for 'scripts' from the data warehouse\n\tsqlStmt = >$sqlStmt<"
# 		fi

# 	## Host specific tools defaults data
# 		Verbose 1 "Updating host specific defaults files"
# 		for host in ${linuxHosts//,/ }; do
# 			defaultsFile="$TOOLSDEFAULTSPATH/$host"
# 			[[ -f ${defaultsFile}.bak ]] && mv -f "$defaultsFile" "${defaultsFile}.bak"
# 			Verbose 1 "\ndefaultsFile = '$defaultsFile'"
# 			sqlStmt="select name,value from defaults where (os is NUll or os in (\"linux\")) and host=\"$host\" and status=\"A\" order by name"
# 			RunSql $sqlStmt
# 			if [[ ${#resultSet[@]} -gt 0 ]]; then
# 				echo "## DO NOT EDIT VALUES IN THIS FILE, THE FILE IS AUTOMATICALLY GENERATED ($(date)) FROM THE DEFAULTS TABLE IN THE DATA WAREHOUSE" > "$defaultsFile"
# 				for ((ii=0; ii<${#resultSet[@]}; ii++)); do
# 					result="${resultSet[$ii]}"
# 					name=${result%%|*}
# 					value=${result##*|}
# 					echo "$name=\"$value\"" >> "$defaultsFile"
# 				done
# 				chgrp 'leepfrog' "$defaultsFile"
# 				chmod 750 "$defaultsFile"
# 			else
# 				Info "Could not retrieve defaults data for '$host' from the data warehouse\n\tsqlStmt = >$sqlStmt<"
# 			fi
# 		done

# 	## Set time stamp on the defaults directory
# 		touch "$TOOLSDEFAULTSPATH"
# fi

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
## 09-28-2017 @ 11.07.59 - (2.0.36)    - dscudiero - Hard code the scripts table name
## 10-02-2017 @ 15.31.24 - (2.0.51)    - dscudiero - fix problem with field index numbers writing out the script specific defaults
## 10-03-2017 @ 11.23.16 - (2.0.52)    - dscudiero - Do not set scriptArgs
## 10-03-2017 @ 11.31.05 - (2.0.56)    - dscudiero - General syncing of dev to prod
## 10-11-2017 @ 07.42.28 - (2.0.57)    - dscudiero - Update debug statements
## 10-16-2017 @ 13.42.45 - (2.0.58)    - dscudiero - Add a level to the verbose statements
## 10-16-2017 @ 13.58.23 - (2.0.59)    - dscudiero - Cosmetic/minor change
## 10-18-2017 @ 15.15.05 - (2.0.60)    - dscudiero - touch the directory to update time date
## 10-27-2017 @ 08.13.09 - (2.0.61)    - dscudiero - Added debug statements
## 10-27-2017 @ 09.18.20 - (2.0.62)    - dscudiero - Remove debug statements
## 11-01-2017 @ 12.37.43 - (2.0.80)    - dscudiero - Fixed an issue with the ignoreList
## 11-01-2017 @ 16.49.38 - (2.0.81)    - dscudiero - Switch to ParseArgsStd
## 12-01-2017 @ 08.33.08 - (2.0.83)    - dscudiero - ignore /mnt directories that end with -test
## 12-06-2017 @ 11.16.01 - (2.0.84)    - dscudiero - Refactored building the defaults data files
## 12-07-2017 @ 10.03.35 - (2.0.85)    - dscudiero - Add time stamp to the top comment in the generated defaults files
## 03-15-2018 @ 10:23:05 - 2.0.86 - dscudiero - Filter out dev6 from build7 devservers
## 03-22-2018 @ 14:07:49 - 2.0.87 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:36:20 - 2.0.88 - dscudiero - D
## 04-19-2018 @ 11:02:38 - 2.0.89 - dscudiero - Change permissions on defaults files
## 04-19-2018 @ 11:06:39 - 2.0.90 - dscudiero - Make backups of the defaults files before writing out new ones
## 05-30-2018 @ 11:18:52 - 2.0.92 - dscudiero - Add updating of the groups/scripts data files
## 05-30-2018 @ 12:54:04 - 2.0.93 - dscudiero - Comment out the echo statements
## 05-30-2018 @ 13:08:06 - 2.0.95 - dscudiero - Add keyId to the output data
## 05-31-2018 @ 16:35:33 - 2.0.97 - dscudiero - Add reports
## 06-01-2018 @ 10:06:41 - 2.0.98 - dscudiero - Add chgrp commands on the scripts and reports files
## 06-08-2018 @ 14:51:26 - 2.0.99 - dscudiero - Add ignorelist to data assigined to the reports object
## 06-11-2018 @ 08:27:10 - 2.1.2 - dscudiero - Add mode processing and messages
## 06-18-2018 @ 09:00:15 - 2.1.2 - dscudiero - Comment out the script section
## 07-11-2018 @ 12:06:47 - 2.1.3 - dscudiero - Remove debug statement
## 07-12-2018 @ 11:06:10 - 2.1.4 - dscudiero - Switch the location of the auth directory
## 07-12-2018 @ 12:25:26 - 2.1.5 - dscudiero - Comment out the reports auth code
## 07-12-2018 @ 13:01:38 - 2.1.5 - dscudiero - Comment out the 'reports auth' section
## 09-13-2018 @ 09:46:31 - 2.1.8 - dscudiero - Update/fix the logic that finds viatable 'servers'
## 11-05-2018 @ 10:27:22 - 2.1.9 - dscudiero - Cosmetic/minor change/Sync
## 11-08-2018 @ 07:03:42 - 2.1.10 - dscudiero - Comment out the toolsDefaults code
## 11-16-2018 @ 09:52:26 - 2.1.11 - dscudiero - Turn on loading defaults files again
## 12-11-2018 @ 15:07:11 - 2.1.12 - dscudiero - Comment out building the defaults files
## 04-10-2019 @ 09:47:45 - 2.1.13 - dscudiero - \ntesting line 1\ntesting line 2\ntesting line 3
## 04-10-2019 @ 09:50:57 - 2.1.14 - dscudiero -  %n testing line 1 %n line 2 %n line 3
## 04-10-2019 @ 10:19:12 - 2.1.15 - dscudiero - Line 1
## 04-10-2019 @ 10:20:01 - 2.1.15 - dscudiero - Line 1
## 04-10-2019 @ 10:22:53 - 2.1.15 - dscudiero - Line 1
## 04-10-2019 @ 10:27:23 - 2.1.15 - dscudiero - line 1
## 04-10-2019 @ 10:28:13 - 2.1.15 - dscudiero - line 1
## 04-10-2019 @ 10:31:50 - 2.1.16 - dscudiero - line 1
## 04-10-2019 @ 10:33:50 - 2.1.17 - dscudiero - line 1
## 04-10-2019 @ 10:36:00 - 2.1.17 - dscudiero - line 10
## 04-10-2019 @ 10:38:23 - 2.1.18 - dscudiero - line 4
## 04-10-2019 @ 10:40:12 - 2.1.18 - dscudiero - lien 1
## 04-10-2019 @ 10:42:03 - 2.1.19 - dscudiero - line 1
## 04-10-2019 @ 10:43:21 - 2.1.19 - dscudiero - line 1
