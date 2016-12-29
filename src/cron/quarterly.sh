#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.12 # -- dscudiero -- 12/29/2016 @ 16:46:55.10
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import FindExecutable GetDefaultsData ParseArgsStd ParseArgs RunSql Msg2 Call
originalArgStr="$*"

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
function EscrowSite {
	local clientList="$*"
	Msg2 > $tmpFile
	Msg2 "$(date)">> $tmpFile
	Msg2 >> $tmpFile
	Msg2 "The following sites have been escrowed, the escrow files can be found at \n^'$courseleafEscrowedSitesDir'" >> $tmpFile
	for client in $(tr ',' ' ' <<< $build7EscrowClients) do
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
