#!/bin/bash
#==================================================================================================
version=2.0.54 # -- dscudiero -- Wed 03/21/2018 @ 16:37:20.17
#==================================================================================================
TrapSigs 'on'
myIncludes=""
Import "$standardInteractiveIncludes $myIncludes"
originalArgStr="$*"
scriptDescription="Goto courseleaf site"

myDebug=true
## Copyright �2015 David Scudiero -- all rights reserved.
#==================================================================================================
# local functions
#==================================================================================================
	#==================================================================================================
	# parse script specific arguments
	#==================================================================================================
	function goto-ParseArgsStd2 {
		#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
		myArgs+=('co|courseleaf|switch||target='/web/courseleaf'|script|Go to .../web/courseleaf')
		myArgs+=('db|db|switch||target='/db'|script|Go to .../db')
	}

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd2 $originalArgStr
[[ $env == '' ]] && env='dev'

dump -r
dump -l myName client env target

#==================================================================================================
## lookup client in clients database
#==================================================================================================
sqlStmt="select hosting from $clientInfoTable where name=\"$client\""
RunSql $sqlStmt
if [[ ${#resultSet[@]} -eq 0 ]]; then
	Error "Client '$client', Env '$env' not found in warehouse.$clientInfoTable table";
	return
fi
hosting=${resultSet[0]}
dump -l hosting

if [[ $hosting == 'leepfrog' ]]; then
	## lookup client in  database
	whereClause="name=\"$client\" and env=\"$env\" and host=\"$hostName\""
	[[ $env = 'pvt' ]] && whereClause="name=\"$client\" and env=\"dev\" and host=\"$hostName\""
	[[ $env = 'test' ]] && client="$client-test" && whereClause="name=\"$client\" and env=\"test\" and host=\"$hostName\""
	sqlStmt="select share,hosting from $siteInfoTable where $whereClause"
	dump -l sqlStmt
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -eq 0 ]]; then
		Error "Client '$client', Env '$env' not found in warehouse.$siteInfoTable table";
		return
	fi
	share=${resultSet[0]}
	dump -l share
	if [[ $env == 'dev' ]]; then
		tgtDir=/mnt/$share/web/$client
	elif [[ $env == 'pvt' ]]; then
		tgtDir=/mnt/$share/web/$client-$userName
	else
		tgtDir=/mnt/$share/$client/$env
	fi
	dump -l tgtDir target

	if [[ $target != "" ]]; then
		if [[ $target == 'debug' ]]; then wizdebug $client -$env
		elif [[ $target == 'clone' ]]; then clone $client -$env -nop
		elif [[ -d $tgtDir$target ]]; then tgtDir=$tgtDir$target;
		fi
	fi
	cd  $tgtDir
else
	pwFile=/home/$userName/.pw2
	unset pwRec
	if [[ -r $pwFile ]]; then
		pwRec=$(grep "^$client" $pwFile)
		if [[ $pwRec != '' ]]; then
			read -ra tokens <<< "$pwRec"
			remoteUser=${tokens[1]}
			remotePw=${tokens[2]}
			remoteHost=${tokens[3]}
			sshpass -p $remotePw ssh $remoteUser@$remoteHost
		fi
	else
		Terminate "Remote site and could not retrieve login information from file: \n^$pwFile."
	fi
fi

return
## Wed Apr 27 15:17:07 CDT 2016 - dscudiero - Switch to use RunSql
## Mon Jun  6 09:30:11 CDT 2016 - dscudiero - Added support for remote sites
## Thu Jul 14 15:08:29 CDT 2016 - fred - Switch LOGNAME for userName
## 03-22-2018 @ 12:36:17 - 2.0.54 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
