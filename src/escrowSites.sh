#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.0.48" # -- dscudiero -- Fri 06/14/2019 @ 07:05:52
#=======================================================================================================================
# Copyright 2019 David Scudiero -- all rights reserved.
# All rights reserved
#=======================================================================================================================
#= Description #========================================================================================================
# Escrow courseleaf sites
# See escrowSites -Help
#=======================================================================================================================
function Main {
 	Msg > $tmpFile
 	Msg $(date) >> $tmpFile
 	Msg >> $tmpFile
 	Msg "The following sites have been escrowed, the escrow files can be found at: \n^'$courseleafEscrowedSitesDir'" >> $tmpFile

 	## Loop through the clients and tar up the entire site
	for token in $(tr ',' ' ' <<< $sitesList); do
 		## Parse off the encryption key from the client token
 		if ($(Contains "$token" '/') == true ); then
	 		client="${token%%/*}"
	 		encryptionKey="${token##*/}"
	 	else 
	 		client="$token"
	 		unset encryptionKey
	 	fi

		Msg "^Processing client: $client" >> $tmpFile
		SetSiteDirsNew "$client"
		[[ ! -d $tarDir ]] && $DOIT mkdir $tarDir
		tarFile=$tarDir/$client@$(date +"%m-%d-%Y").tar
		[[ -f $tarFile ]] && rm -f $tarFile
		dump -1 -t tarFile

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
			[[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
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
	Msg "^Escrow courseleaf sites"
	Msg "^	1) Tar up the next, curr, test"
	Msg "^	2) If a password was supplied with the client data the an additional encrypted file will be created"
	Msg "^	3) Notifications are sent out"
	Msg
	Msg "^- If 'siteList' is not supplied it will use the list defined in the"
	Msg "^^data warehouse ($warehouseDbHost / $warehouseDbName)  'defaults' table for variable 'escrowClients'"
	Msg "^^^i.e. '$escrowClients'"
	Msg "^- If 'emailList' is not supplied it will use the list defined in the 'defaults'"
	Msg "^^data warehouse ($warehouseDbHost / $warehouseDbName)  'defaults' table for variable 'escrowEmailAddrs'"
	Msg "^^^i.e. '$escrowEmailAddrs'"
	Msg
	Msg "^*** The script MUST be run on the host where the sites are located"
	Msg
	Msg "^E.g. escrowSites -siteList \"site1/passcode1,site2/passcpde2\" -emailList \"user@leepfrog.com,user2@leepfrog.com\""
}

function escrowSites-testMode  { # or testMode-local
	tmpFile="/dev/tty"
	emailList="dscudiero@leepfrog.com"
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
	myArgs="clientList|clientList|option|clientList|A comma separated list of clientCodes[/password];"
	myArgs+="emailList|emailList|option|emailList|A comma separated list of email addresses;"
	export myArgs="$myArgs"
	ParseArgs $*

	[[ -z $sitesList ]] && sitesList="$escrowClients"
	[[ -z $emailList ]] && emailList="$escrowEmailAddrs"
	[[ -z $sitesList ]] && Terminate "No sites were supplied on call"
	sendMail=true

	tmpFile=$(MkTmpFile $myName)
	tarDir="$courseleafEscrowedSitesDir"
	dump -1 -t sitesList emailList tmpFile tarDir

	SetFileExpansion -off
	excludes="*.git* *.gz *.bak *.old *-Copy* RECOVERED-* RESTORED-* */attic"
	for exclude in $excludes; do
		tarOpts="$tarOpts --exclude $exclude"
	done
	tarOpts="$tarOpts -uf"
	SetFileExpansion

	gpgOpts="--yes --batch --symmetric -z 9 --require-secmem --cipher-algo AES256"
	gpgOpts="$gpgOpts --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000"
	gpgOpts="$gpgOpts --compress-algo BZIP2"

	dump -1 -t tarOpts gpgOpts
	
	return 0;
} ## Initialization

#============================================================================================================================================
[[ -z $TOOLSPATH ]] && { echo -e "\n\t*Error* -- Insufficient execution environment\n"; exit; }
TrapSigs 'on'
myIncludes="$standardInteractiveIncludes SetSiteDirsNew PushPop SetFileExpansion HelpNew"
Import $myIncludes

Initialization $*
Hello

if [[ $batchMode != true ]]; then
	verifyMsg="You are asking to create escrow files for: '${sitesList//,/, }'"
	VerifyContinue "$verifyMsg"
fi

Main $ArgStrAfterInit

## Log in the activity log
sqlStmt="insert into $activityLogTable values(null,\"$userName\",null,null,\"$myName\",\"siteList:${sitesList//,/, }, emailList:${emailList//,/, }\",NOW())";
RunSql $sqlStmt

Goodbye

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 06-13-2019 @ 07:19:53 - 1.0.3 - dscudiero -  Add exclude items to the tar call
## 06-13-2019 @ 09:48:59 - 1.0.32 - dscudiero -  Updated help module Adde -excludes to the tar call Added verify if not running in batch mode
## 06-13-2019 @ 09:56:07 - 1.0.37 - dscudiero -  Check execution environment
## 06-13-2019 @ 11:12:19 - 1.0.38 - dscudiero -  Add logging in the activity log
## 06-13-2019 @ 11:20:41 - 1.0.39 - dscudiero - Cosmetic / Miscellaneous cleanup / Sync
## 06-13-2019 @ 11:27:31 - 1.0.40 - dscudiero - Add/Remove debug statements
## 06-13-2019 @ 11:30:52 - 1.0.41 - dscudiero - Cosmetic / Miscellaneous cleanup / Sync
## 06-14-2019 @ 08:28:06 - 1.0.48 - dscudiero -  Fix up tar options
