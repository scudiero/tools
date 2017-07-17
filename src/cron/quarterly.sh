#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.38 # -- dscudiero -- Mon 07/17/2017 @  8:09:56.22
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
	[[ -z $clientList ]] && return 0
	local tmpFile=$(MkTmpFile $FUNCNAME)
	tarDir=$courseleafEscrowedSitesDir

 	Msg2 > $tmpFile
 	Msg2 $(date) >> $tmpFile
 	Msg2 >> $tmpFile
 	Msg2 "The following sites have been escrowed, the escrow files can be found at \n^'$courseleafEscrowedSitesDir'" >> $tmpFile

 	for client in $(tr ',' ' ' <<< $clientList); do
		Msg2 "^Processing client: $client" >> $tmpFile
		SetSiteDirs 'setDefault'
		cd $prodSiteDir
		[[ ! -d $tarDir ]] && mkdir $tarDir
		tarFile=$tarDir/$client@$(date +"%m-%d-%Y").tar.xz
		[[ -f $tarFile ]] && rm -f $tarFile

		Msg2 >> $tmpFile
		unset dirsToTar
		for env in test next curr public; do
			[[ -d ./$env ]] && dirsToTar="$env $dirsToTar"
		done
		dirsToTar=$(Trim "$dirsToTar")
		Msg2 "^^Tarring directories: $(echo $dirsToTar | tr ' ' ',')" >> $tmpFile

		set +f
		$DOIT tar -cJf $tarFile $dirsToTar; rc=$?
		rc=$?; [[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
		chown leepfrog $tarFile
		chmod 669 $tarFile
		Msg2 "^^Escrow file generated at: $tarFile" >> $tmpFile
	done

	## Send emails
dump escrowEmailAddrs
escrowEmailAddrs='dscudiero@leepfrog.com'
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
## 07-17-2017 @ 08.08.58 - (2.1.37)    - dscudiero - move escrowClient functionality into script
## 07-17-2017 @ 08.18.36 - (2.1.38)    - dscudiero - General syncing of dev to prod
