#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.27 # -- dscudiero -- Mon 07/17/2017 @  7:34:32.51
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
Import GetDefaultsData ParseArgsStd ParseArgs Msg2 FindExecutable Call
originalArgStr="$*"
Here 0

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
function EscrowSite {
Here 2
	local clientList="$*"
	local tmpFile=$(MkTmpFile $FUNCNAME)
Here 3
echo "tmpFile = '$tmpFile'"
echo "clientList = '$clientList'"
	Msg2 > $tmpFile
	Msg2 "$(date)">> $tmpFile
	Msg2 >> $tmpFile
	Msg2 "The following sites have been escrowed, the escrow files can be found at \n^'$courseleafEscrowedSitesDir'" >> $tmpFile
# 	for client in $(tr ',' ' ' <<< $clientList) do
# echo "client = '$client'"
# 		Msg2 "^$client"
# 		Call 'escrowClient' "$client" "$scriptArgs"
# 	done
# 	Msg2 >> $tmpFile
# 	if [[ $sendMail == true ]]; then
# 		Msg2 "\nEmails sent to: $escrowEmailAddrs\n" >> $tmpFile
# 		for emailAddr in $(tr ',' ' ' <<< $escrowEmailAddrs); do
# 			mail -s "$myName: Clients escrowed" $emailAddrs < $tmpFile
# 		done
# 	fi

# 	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
}

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
Here 1
# GetDefaultsData $myName
# Here 1a
# ParseArgsStd
# Here 1b
# scriptArgs="$*"

# sendMail=true

Here 1
echo "hostName = '$hostName'"
echo "mojaveEscrowClients = '$mojaveEscrowClients'"

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
## 07-17-2017 @ 07.16.39 - (2.1.17)    - dscudiero - add debug
## 07-17-2017 @ 07.17.55 - (2.1.18)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.21.02 - (2.1.20)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.23.01 - (2.1.21)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.26.07 - (2.1.22)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.29.32 - (2.1.23)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.30.23 - (2.1.24)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.31.31 - (2.1.25)    - dscudiero - General syncing of dev to prod
## 07-17-2017 @ 07.32.25 - (2.1.26)    - dscudiero - g
## 07-17-2017 @ 07.34.35 - (2.1.27)    - dscudiero - General syncing of dev to prod
