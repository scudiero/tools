#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.34 # -- dscudiero -- Mon 07/17/2017 @  7:53:27.21
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import GetDefaultsData ParseArgsStd ParseArgs Msg2 FindExecutable Call
originalArgStr="$*"

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
function EscrowSite {
	local clientList="$*"
	local tmpFile=$(MkTmpFile $FUNCNAME)

 	Msg2 > $tmpFile
 	Msg2 $(date) >> $tmpFile
 	Msg2 >> $tmpFile
 	Msg2 "The following sites have been escrowed, the escrow files can be found at \n^'$courseleafEscrowedSitesDir'" >> $tmpFile
 	for client in $(tr ',' ' ' <<< $clientList); do
		Msg2 "^$client"
		Call 'escrowClient' "$client" "$scriptArgs"
	done
	Msg2 >> $tmpFile
	if [[ $sendMail == true ]]; then
		Msg2 "\nEmails sent to: $escrowEmailAddrs\n" >> $tmpFile
		for emailAddr in $(tr ',' ' ' <<< $escrowEmailAddrs); do
			mail -s "$myName: Clients escrowed" $emailAddrs < $tmpFile
		done
 	fi

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
}

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
GetDefaultsData $myName
ParseArgsStd
scriptArgs="$*"
sendMail=true

#==================================================================================================
# Main
#==================================================================================================
case "$hostName" in
	mojave)
			[[ -n $mojaveEscrowClients ]] && EscrowSite "$mojaveEscrowClients"
			;;
	build5)
			[[ -n $build5EscrowClients ]] && EscrowSite "$build5EscrowClients"
			;;
	build7)
			[[ -n $build7EscrowClients ]] && EscrowSite "$build7EscrowClients"
			;;
esac

#========================================================================================================================
## Bye-bye
[[ $fork == true ]] && wait
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Dec 29 16:50:40 CST 2016 - dscudiero - Updated the code to escrow sites to generalize
## Thu Jan  5 14:50:11 CST 2017 - dscudiero - Switch to use RunSql2
## Thu Feb  9 08:06:49 CST 2017 - dscudiero - make sure we are using our own tmpFile
## 07-17-2017 @ 07.52.31 - (2.1.33)    - dscudiero - Fix script syntax error on for statement
## 07-17-2017 @ 07.53.51 - (2.1.34)    - dscudiero - uncomment call to escrowClient
