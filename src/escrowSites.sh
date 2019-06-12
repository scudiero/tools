#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.0" # -- dscudiero -- Wed 06/12/2019 @ 16:30:16
#=======================================================================================================================
#= Description #========================================================================================================
# Excrow courseleaf sites
#	1) Tar up the next, curr, test
#	2) If a password was supplied with the client data the resultant tar file from #1 will be encrypted
#	3) Notifications are sent out
#
# Usage: escrowSites -siteList <sitesList> -emailList <emailList>
#	sitesList - A comma separated list of clientCodes[/password], if not supplied it will use the list defined in the defaults 
#				data warehouse table for variable 'escrowClients'
#	emailList - A comma separated list of email addresses, if not supplied it will use the list defined in the defaults 
#				data warehouse table for variable 'escrowEmailAddrs'
#
# Script MUST be run on each host where sites are located
#
#	e.g. escrowSites -siteList "site1/passcode1,site2/passcpde2" -emailList "user@leepfrog.com,user2@leepfrog.com"
#
#=======================================================================================================================
function Main {
 	Msg > $tmpFile
 	Msg $(date) >> $tmpFile
 	Msg >> $tmpFile
 	Msg "The following sites have been escrowed, the escrow files can be found at: \n^'$courseleafEscrowedSitesDir'" >> $tmpFile

 	## Loop through the clients and tar up the entire site
	for token in $(tr ',' ' ' <<< $sitesList); do
		dump -n token
 		## Parse off the encryption key from the client token
 		if ($(Contains "$token" '/') == true ); then
	 		client="${token%%/*}"
	 		encryptionKey="${token##*/}"
	 	else 
	 		client="$token"
	 		unset encryptionKey
	 	fi
		dump -t client encryptionKey

		Msg "^Processing client: $client" >> $tmpFile
		SetSiteDirsNew "$client"
		[[ ! -d $tarDir ]] && $DOIT mkdir $tarDir
		tarFile=$tarDir/$client@$(date +"%m-%d-%Y").tar
		[[ -f $tarFile ]] && rm -f $tarFile
		dump -1 tarFile
		## tar up the next and curr sites	
		if [[ -d $nextDir ]]; then
			Pushd $(dirname $nextDir)
			unset dirsToTar
			for env in next curr; do
				[[ -d ./$env ]] && dirsToTar="$env $dirsToTar"
			done
			dirsToTar=$(Trim "$dirsToTar")
			Msg "^^Tarring directories: $(echo $dirsToTar | tr ' ' ',')" >> $tmpFile
			set +f
			$DOIT tar $tarOpts $tarFile $dirsToTar; rc=$?
			rc=$?; [[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
		fi
		## tar up the test site
		if [[ -d $testDir ]]; then
			Pushd $(dirname $testDir)
			dirsToTar="test"
			Msg "^^Tarring directories: $(echo $dirsToTar | tr ' ' ',')" >> $tmpFile
			set +f
			$DOIT tar $tarOpts $tarFile $dirsToTar; rc=$?
			rc=$?; [[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
		fi
		## Set file ownership / permissions
		$DOIT chgrp leepfrog $tarFile
		$DOIT chmod 660 $tarFile

		## Encrypt the file if we have a password
		[[ -n encryptionKey ]] && $DOIT gpg $gpgOpts --passphrase "$encryptionKey" -c "$tarFile"

		Msg "^^Escrow file generated at: $tarFile" >> $tmpFile
		[[ -n encryptionKey ]] && Msg "^^^Encrypted file: ${tarFile}.gpg" >> $tmpFile
	done

	## Send out emails
	Msg >> $tmpFile
	if [[ $sendMail == true && -n $emailList ]]; then
		Msg "\nEmails sent to: $emailList\n" >> $tmpFile
		for emailAddr in $(tr ',' ' ' <<< $emailList); do
			mail -s "$myName: Clients escrowed" $emailAddr < $tmpFile
		done
	fi

	return 0
} ## Main

#=======================================================================================================================
# Standard call back functions
#=======================================================================================================================
function escrowSites-Goodbye  {
	SetFileExpansion 'on' ; rm -rf $tmpRoot/${myName}* >& /dev/null ; SetFileExpansion
	return 0
}

function escrowSites-Help  {
	return 0
}

function escrowSites-testMode  { # or testMode-local
	tmpFile="/dev/tty"
	return 0
}

#============================================================================================================================================
# Script initialization 
#============================================================================================================================================
function Initialization {
	#=======================================================================================================================
	# Standard arg parsing and initialization
	#=======================================================================================================================
	SetDefaults $myName
	myArgs="clientList|clientList|option|clientList|;"
	myArgs+="emailList|emailList|option|emailList|;"
	export myArgs="$myArgs"
	ParseArgs $*

	Hello

	[[ -z $sitesList ]] && sitesList="$escrowClients"
	[[ -z $emailList ]] && emailList="$escrowEmailAddrs"
	[[ -z $sitesList ]] && Terminate "No sites were supplied on call"

	tmpFile=$(MkTmpFile $FUNCNAME)
	tarDir="$courseleafEscrowedSitesDir"

	tarOpts="-uf"

	gpgOpts="--yes --batch --symmetric -z 9 --require-secmem --cipher-algo AES256"
	gpgOpts="$gpgOpts --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000"
	gpgOpts="$gpgOpts --compress-algo BZIP2"

	return 0;
} ## Initialization

#============================================================================================================================================
TrapSigs 'on'
myIncludes="Hello SetSiteDirsNew PromptNew MkTmpFile PushPop"
Import $myIncludes

Initialization $*
Main $ArgStrAfterInit

Goodbye

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
