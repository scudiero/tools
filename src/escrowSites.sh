#!/bin/bash
#XO NOT AUTOVERSION
#=======================================================================================================================
version="1.1.1" # -- dscudiero -- Mon 07/01/2019 @ 15:40:00
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
 	Msg "The following sites have been escrowed, the escrow files can be found at: \n^'$outDir'" >> $tmpFile

 	## Loop through the clients and tar up the entire site
	for token in $(tr ',' ' ' <<< $clientList); do
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
		else
			Warning "Could not locate next/curr directory, skipping"
		fi
		## tar up the test site
		if [[ -d $testDir ]]; then
			Pushd $(dirname $testDir)
			dirsToTar="test"
			Msg "^^Tarring directories: $(echo $dirsToTar | tr ' ' ',')" >> $tmpFile
			set +f
			$DOIT tar $tarOpts $tarFile $dirsToTar; rc=$?
			rc=$?; [[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
		else
			Warning "Could not locate test directory, skipping"
		fi
		## Set file ownership / permissions
		if [[ -f $tarFile ]]; then
			$DOIT chgrp leepfrog $tarFile
			$DOIT chmod 660 $tarFile

			## Encrypt the file if we have a password
			[[ -n encryptionKey ]] && $DOIT gpg $gpgOpts --passphrase "$encryptionKey" -c "$tarFile"

			Msg "^^Escrow file generated at: $tarFile" >> $tmpFile
			[[ -n encryptionKey ]] && Msg "^^^Encrypted file: ${tarFile}.gpg" >> $tmpFile
		else
			Terminate "Sorry, tar file not generated for '$client'"
		fi
	done

	## Send out emails
	Msg >> $tmpFile
	if [[ -n $emailList ]]; then
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
	Msg "^*** The script MUST be run on the Linux host (i.e. build7) where the sites are served from"
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
	helpSet='client'
	SetDefaults $myName
	myArgs+="password|password|option|password|A password to be used to generate a gpg encrypted file.;"
	myArgs+="emailList|emailList|option|emailList|A comma separated list of email addresses.;"
	myArgs+="outDir|outDir|option|outDir|The fully qualified path to the output directory.;"
	export myArgs="$myArgs"
	ParseArgs $*

	PromptNew client 'What client do you wish to work with?'  'client'
	PromptNew password 'Password for the encrypted file, if not specified no encrypted file will be created?' "*optional*"
	PromptNew outDir 'Where do you wish the generated tar/gpg files to be placed?' '*dir*'
	PromptNew emailList 'A comma separated list of email address to be notified by email when processing is completed?' '*any*'
	[[ -n $password ]] && clientList="$client/$password" || clientList="$client"
	dump -1 -t client password outDir emailList clientList

	tmpFile=$(MkTmpFile $myName)
	[[ -n $outDir ]] && tarDir="$outDir" || tarDir="$courseleafEscrowedSitesDir"
	[[ ! -d $tarDir ]] && mkdir "$tarDir"
	dump -1 -t clientList emailList tmpFile tarDir

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

Hello
Initialization $*

[[ -z $client ]] && Terminate "Sorry, a value must be specified for 'client'"
[[ ! -d $tarDir ]] && Terminate "Sorry, Could not locate output directory: '$tarDir'"

## Check with the user to verify that we should continue
if [[ $batchMode != true ]]; then
	unset verifyArgs
	verifyArgs+=("clientList:${clientList//,/, }")
	verifyArgs+=("Output Directory:$tarDir")
	[[ -n $emailList ]] && verifyArgs+=("Notification emails:$emailList")
	verifyContinueDefault='Yes'
	VerifyContinue "You are asking to create escrow files for"
	tmpFile="/dev/tty"
fi

[[ -z $emailList ]] && Warning "No notify emails address were supplied on call, no completion notifications will be sent out"
Main $ArgStrAfterInit

## Log in the activity log
sqlStmt="insert into $activityLogTable values(null,\"$userName\",null,null,\"$myName\",null,\"clientList:${clientList//,/, }, emailList:${emailList//,/, }\",NOW())";
RunSql $sqlStmt

Goodbye 0

#============================================================================================================================================
## Check-in log
#============================================================================================================================================
## 06-13-2019 @ 07:19:53 - 1.0.3 - dscudiero -  Add exclude items to the tar call
## 06-13-2019 @ 09:48:59 - 1.0.32 - dscudiero -  Updated help module Added -excludes to the tar call Added verify if not running in batch mode
## 06-13-2019 @ 09:56:07 - 1.0.37 - dscudiero -  Check execution environment
## 06-13-2019 @ 11:12:19 - 1.0.38 - dscudiero -  Add logging in the activity log
## 06-13-2019 @ 11:20:41 - 1.0.39 - dscudiero - Cosmetic / Miscellaneous cleanup / Sync
## 06-13-2019 @ 11:27:31 - 1.0.40 - dscudiero - Add/Remove debug statements
## 06-13-2019 @ 11:30:52 - 1.0.41 - dscudiero - Cosmetic / Miscellaneous cleanup / Sync
## 06-14-2019 @ 08:28:06 - 1.0.48 - dscudiero -  Fix up tar options
## 06-17-2019 @ 07:11:45 - 1.0.49 - dscudiero -  Fix sql inserting into activityLog
## 06-20-2019 @ 16:38:59 - 1.0.74 - dscudiero -  Added ability to specify the output directory on the call
## 06-24-2019 @ 10:27:27 - 1.0.91 - dscudiero -  Switch arguments to be a single client at a time
## 06-25-2019 @ 08:59:58 - 1.0.92 - dscudiero -  Make sure that clientList is set before calling main
## 07-01-2019 @ 15:38:25 - 1.1.0 - dscudiero -  Check to make sure a tar file is generated
## 07-01-2019 @ 15:40:09 - 1.1.1 - dscudiero - Tweak messaging
