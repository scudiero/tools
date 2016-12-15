#!/bin/bash
#==================================================================================================
version=2.1.10 # -- dscudiero -- 12/14/2016 @ 11:22:55.99
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye' #imports="$imports "
Import "$imports"
originalArgStr="$*"
scriptDescription="Clone a set of sites"

#==================================================================================================
# Clone a set of sites using the cloneEnv script
#==================================================================================================
#==================================================================================================
# Copyright ©2014 David Scudiero -- all rights reserved.
# 06-17-15 -- 	dgs - Initial coding
# 07-17-15 --	dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
mode='create'
## Get the site name suffix
siteSuffix='-luc'
[[ $scriptData2 != '' ]] && siteSuffix='$scriptData2'

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
## Parse script specific arguments
while [[ $ii -lt ${#argArray[*]} ]]; do
	argToken=$(Lower ${argArray[$ii]})
	#dump argToken
	if [[ "${argToken:0:2}" == '-r' ]]; then 
		mode='remove'
	fi
	(( ii += 1 ))
done

## Get the list of sites to work with
[[ $client == '' && $scriptData1 != '' ]] && client="$scriptData1"

Hello
if [[ $client == '' ]]; then Init 'getClient'; fi 
VerifyContinue "You are asking to $mode 'xxx$siteSuffix' test sites for the following clients:\n\n$client\n"

#==================================================================================================
## Main
#==================================================================================================
for site in $client; do
	sqlStmt="select idx from $clientInfoTable where name=\"$site\" "
	RunSql 'mysql' $sqlStmt
	clientId=${resultSet[0]}
	if [[ "$clientId" = '' ]]; then
		Msg2 "Client value of '$site' not found in leepfrog.$clientInfoTable" | tee $logFile
		continue
	else 
		sqlStmt="select siteId from $siteInfoTable where clientId=\"$clientId\" and host = \"$hostName\" and env = \"next\""
		RunSql 'mysql' $sqlStmt
		siteId=${resultSet[0]}
		if [[ "$siteId" != '' ]]; then
			Msg2 "processing: $site" | tee $logFile
			if [[ $hostName = 'mojave' ]]; then siteDir="/mnt/dev6/web/$site$siteSuffix"; else siteDir="/mnt/dev9/web/$site$siteSuffix"; fi
			if [[ $mode = 'remove' ]]; then 
				if [[ -d $siteDir ]]; then Msg2 "^Removing $siteDir"; $DOIT rm -rf $siteDir; fi
				if [[ -d $siteDir.DELETE ]]; then Msg2 "^Removing $siteDir.DELETE"; $DOIT rm -rf $siteDir.DELETE; fi
			else
				cmdStr="cloneEnv $site -n -a -f -q -nop -suffix luc -e noaddress@mailbb.leepfrog.com"
				printf "$cmdStr" | tee $logFile
				$DOIT $cmdStr | tee $logFile
				if [[ -d $siteDir ]]; then 
					$DOIT sed -i s'_^navlinks:Administration|Republish Site_//navlinks:Administration|Republish Site_' $siteDir/web/courseleaf/index.tcf
					$DOIT sed -i s'_^navlinks:Administration|Course Import_//navlinks:Administration|Course Import_' $siteDir/web/courseleaf/index.tcf
					$DOIT sed -i s'_^navlinks:Administration|Rebuild PageDB_//navlinks:Administration|Rebuild PageDB_' $siteDir/web/courseleaf/index.tcf
					$DOIT sed -i s'_^mapfile:production_//mapfile:production_' $siteDir/courseleaf.cfg
					cd $siteDir/web/courseleaf
					$DOIT ./courseleaf.cgi -r /courseleaf/index.html | xargs printf "\t%s\n" | tee $logFile
				fi
			fi
		else 
			Msg2 "*** skipping: $site" | tee $logFile
		fi		
	fi	
done

#####################################################################################################
## Done
#####################################################################################################
#Alert
Goodbye 0
## Wed Apr 27 16:15:56 CDT 2016 - dscudiero - Switch to use RunSql
