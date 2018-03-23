## XO NOT AUTOVERSION
#===================================================================================================
#version="2.0.14" # -- dscudiero -- Fri 03/23/2018 @ 16:55:25.14
#===================================================================================================
# Start a remote session via ssh
# StartRemoteSession userid@domain [command]
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function StartRemoteSession {
	myIncludes="ProtectedCall StringFunctions"
	Import "$standardIncludes $myIncludes"

	local remoteUserAtHost=$1; shift
	local remoteCommand="$*"

	local commmandPrefix pwRec lookupKey tokens remoteHost remoteUser remotePw remoteDomain
	unset pwRec

	remoteUser=$(cut -d '@' -f1 <<< $remoteUserAtHost)
	remoteDomain=$(cut -d '@' -f2 <<< $remoteUserAtHost)
	remoteHost=$(cut -d '.' -f1 <<< $remoteDomain)
	lookupKey=$remoteHost

	#E Does the user have sshpass and a .pw2 file in their home directory
	local pwFile=$HOME/.pw2
	whichOut=$(ProtectedCall "which sshpass 2> /dev/null")
	if [[ $whichOut != '' && -r $pwFile && $lookupKey != '' ]]; then
		pwRec=$(grep "^$lookupKey" $pwFile)
		if [[ $pwRec != '' ]]; then ## [0]=key, [1]=userid, [2]=password, [3]=remoteHost
			read -ra tokens <<< "$pwRec"
			[[ ${tokens[3]} != '' ]] && remoteUserAtHost="${tokens[1]}@${tokens[3]}" || remoteUserAtHost="${tokens[1]}@${remoteDomain}"
			commmandPrefix="sshpass -p ${tokens[2]}"
		fi
	fi

	[[ $(Contains "$remoteUserAtHost" '.') == false ]] && remoteUserAtHost="${remoteUserAtHost}.leepfrog.com"
	#[[ $(Contains ",$slowHosts," ",$remoteHost,") == true ]] && Note "Target host has been found to be a bit slow, please be patient" && Msg
	$commmandPrefix ssh -t $remoteUserAtHost $DISPATCHER $remoteCommand
	return 0
} ## StartRemoteSession
export -f StartRemoteSession

#===================================================================================================
# Check-in Log
#===================================================================================================

## Wed Jan  4 13:54:32 CST 2017 - dscudiero - General syncing of dev to prod
## 09-22-2017 @ 12.14.39 - ("2.0.12")  - dscudiero - Added to includes
## 03-22-2018 @ 13:16:53 - 2.0.13 - dscudiero - Updated for Msg/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 16:57:26 - 2.0.14 - dscudiero - Msg3 -> Msg
