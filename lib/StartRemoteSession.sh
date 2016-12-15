## XO NOT AUTOVERSION
#===================================================================================================
version="2.0.6" # -- dscudiero -- 12/15/2016 @ 13:38:07.17
#===================================================================================================
# Start a remote session via ssh
# StartRemoteSession userid@domain [command]
#===================================================================================================
# Copyright 2016 David Scudiero -- all rights reserved.
# All rights reserved
#===================================================================================================

function StartRemoteSession {
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
	[[ $(Contains ",$slowHosts," ",$remoteHost,") == true ]] && Msg2 $N "Target host has been found to be a bit slow, please be patient" && Msg2
	$commmandPrefix ssh $remoteUserAtHost $DISPATCHER $remoteCommand
	return 0
} ## StartRemoteSession
export -f StartRemoteSession

#===================================================================================================
# Check-in Log
#===================================================================================================

