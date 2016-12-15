#!/bin/bash
#==================================================================================================
version=2.0.52 # -- dscudiero -- 12/14/2016 @ 11:25:54.78
#==================================================================================================
TrapSigs 'on'
imports='GetDefaultsData ParseArgs ParseArgsStd' #imports="$imports "
Import "$imports"
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
	function parseArgs-goto {
		# argList+=(argFlag,minLen,type,scriptVariable,exCmd,helpSet,helpText)  #type in {switch,switch#,option,help}
		argList+=(-courseleaf,2,switch,,target='/web/courseleaf',script,"Go to .../web/courseleaf")
		argList+=(-cimc,4,switch,,target='/web/courseadmin',script,"Go to .../web/courseadmin")
		argList+=(-cimp,4,switch,,target='/web/programadmin',script,"Go to .../web/programadmin")
		argList+=(-db,2,switch,,target='/db',script,"Go to .../web/programadmin")
		argList+=(-debug,2,switch,,target='debug',script,"Start wizDebug")
		argList+=(-clone,2,switch,,target='clone',script,"Clone the site")
	}

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
helpSet='script,client,env'
GetDefaultsData $myName
ParseArgsStd
[[ $env == '' ]] && env='dev'

dump -r
dump -l myName client env target

#==================================================================================================
## lookup client in clients database
#==================================================================================================
sqlStmt="select hosting from $clientInfoTable where name=\"$client\""
RunSql 'mysql' $sqlStmt
if [[ ${#resultSet[@]} -eq 0 ]]; then
	Msg2  $E "Client '$client', Env '$env' not found in warehouse.$clientInfoTable table";
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
	RunSql 'mysql' $sqlStmt
	if [[ ${#resultSet[@]} -eq 0 ]]; then
		Msg2  $E "Client '$client', Env '$env' not found in warehouse.$siteInfoTable table";
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
		Msg2 $T "Remote site and could not retrieve login information from file: \n^$pwFile."
	fi
fi

return
## Wed Apr 27 15:17:07 CDT 2016 - dscudiero - Switch to use RunSql
## Mon Jun  6 09:30:11 CDT 2016 - dscudiero - Added support for remote sites
## Thu Jul 14 15:08:29 CDT 2016 - fred - Switch LOGNAME for userName
