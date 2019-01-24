#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version="2.1.53" # -- dscudiero -- Wed 01/23/2019 @ 10:29:22
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="SetSiteDirs ProtectedCall StringFunctions"
Import "$standardIncludes $myIncludes"

originalArgStr="$*"

#=======================================================================================================================
# Declare local variables and constants
#=======================================================================================================================
function EscrowSite {
	local clientList="$*"
	[[ -z $clientList ]] && return 0
	local tmpFile=$(MkTmpFile $FUNCNAME)
	tarDir=$courseleafEscrowedSitesDir

 	Msg > $tmpFile
 	Msg $(date) >> $tmpFile
 	Msg >> $tmpFile
 	Msg "The following sites have been escrowed, the escrow files can be found at \n^'$courseleafEscrowedSitesDir'" >> $tmpFile

 	for client in $(tr ',' ' ' <<< $clientList); do
 		## Parse off the encryption key
 		if ($(Contains "$token" '/') == true ); then
	 		client="${token%%/*}"
	 		encryptionKey="${token##*/}"
	 	else 
	 		client="$token"
	 		unset encryptionKey
	 	fi

		Msg "^Processing client: $client" >> $tmpFile
		SetSiteDirs
		cd $(dirname $nextDir)
		[[ ! -d $tarDir ]] && mkdir $tarDir
		tarFile=$tarDir/$client@$(date +"%m-%d-%Y").tar.xz
		[[ -f $tarFile ]] && rm -f $tarFile

		Msg >> $tmpFile
		unset dirsToTar
		for env in test next curr public; do
			[[ -d ./$env ]] && dirsToTar="$env $dirsToTar"
		done
		dirsToTar=$(Trim "$dirsToTar")
		Msg "^^Tarring directories: $(echo $dirsToTar | tr ' ' ',')" >> $tmpFile

		set +f
		$DOIT tar -cJf $tarFile $dirsToTar; rc=$?
		rc=$?; [[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
		chgrp leepfrog $tarFile
		chmod 660 $tarFile
		[[ -n encryptionKey ]] && gpg $gpgOpts --passphrase "$encryptionKey" -c "$tarFile"

		Msg "^^Escrow file generated at: $tarFile" >> $tmpFile
		[[ -n encryptionKey ]] && Msg "^^^Encrypted file: ${tarFile}.gpg" >> $tmpFile
	done

	## Send emails
		Msg >> $tmpFile
		if [[ $sendMail == true ]]; then
			Msg "\nEmails sent to: $escrowEmailAddrs\n" >> $tmpFile
			for emailAddr in $(tr ',' ' ' <<< $escrowEmailAddrs); do
				mail -s "$myName: Clients escrowed" $emailAddr < $tmpFile
			done
		fi

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
} #EscrowSite

function RollupProcessLog {
	## Roll up the weeks processlog db table
	Msg "\n*** Processlog rollup -- Starting ***"
	cd $TOOLSPATH/Logs
	outFile="$(date '+%m-%d-%y').processLog.xls"
	## Get the column names
	sqlStmt="select column_name from information_schema.columns where table_schema = \"$warehouseDb\" and table_name = \"$processLogTable\"";
	RunSql $sqlStmt
	resultString="${resultSet[@]}" ; resultString=$(tr " " "\t" <<< $resultString)
	echo "$resultString" >> $outFile
	SetFileExpansion 'off'
	sqlStmt="select * from $processLogTable"
	RunSql $sqlStmt
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		for result in "${resultSet[@]}"; do
		 	resultString=$result; resultString=$(tr "|" "\t" <<< $resultString)
		 	echo "$resultString" >> $outFile
		done
		case "$(date +"%m")" in
			01|02|03) quarter=1 ;;
			04|05|06) quarter=2 ;;
			07|08|09) quarter=3 ;;
			10|11|12) quarter=4 ;;
		esac
		quarter="${quarter}Q$(date +"%y")"
		ProtectedCall "tar -cvzf \"$quarter.processLog.tar\" $outFile --remove-files > /dev/null 2>&1"
	fi
	sqlStmt="truncate $processLogTable"
	RunSql $sqlStmt
	SetFileExpansion
	Msg "*** Processlog rollup -- Completed ***"
} #RollupProcessLog

#=======================================================================================================================
# Standard argument parsing and initialization
#=======================================================================================================================
source <(CallC toolsSetDefaults $myName);
ParseArgs $originalArgStr
scriptArgs="$*"
sendMail=true

gpgOpts="--yes --batch --symmetric -z 9 --require-secmem --cipher-algo AES256"
gpgOpts="$gpgOpts --s2k-cipher-algo AES256 --s2k-digest-algo SHA512 --s2k-mode 3 --s2k-count 65000000"
gpgOpts="$gpgOpts --compress-algo BZIP2"

#==================================================================================================
# Main
#==================================================================================================
case "$hostName" in
	mojave)
			[[ -n $escrowClients ]] && EscrowSite "$escrowClients"
			# RollupProcessLog
			;;
	build7)
			[[ -n $escrowClients ]] && EscrowSite "$escrowClients"
			;;
esac

#========================================================================================================================
## Bye-bye
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Dec 29 16:50:40 CST 2016 - dscudiero - Updated the code to escrow sites to generalize
## Thu Jan  5 14:50:11 CST 2017 - dscudiero - Switch to use RunSql
## Thu Feb  9 08:06:49 CST 2017 - dscudiero - make sure we are using our own tmpFile
## 07-17-2017 @ 07.52.31 - (2.1.33)    - dscudiero - Fix script syntax error on for statement
## 07-17-2017 @ 07.53.51 - (2.1.34)    - dscudiero - uncomment call to escrowClient
## 07-17-2017 @ 08.08.58 - (2.1.38)    - dscudiero - move escrowClient functionality into script
## 07-17-2017 @ 14.00.52 - (2.1.42)    - dscudiero - Many updates
## 09-21-2017 @ 10.02.41 - (2.1.43)    - dscudiero - Add rollup of the processlog
## 09-21-2017 @ 10.15.16 - (2.1.44)    - dscudiero - Change the name of the tar file to reflect the quarter number
## 09-27-2017 @ 07.52.12 - (2.1.45)    - dscudiero - Switched to Msg
## 10-11-2017 @ 10.37.49 - (2.1.46)    - dscudiero - Switch to use FindExecutable -run
## 03-22-2018 @ 12:47:12 - 2.1.47 - dscudiero - Updated for Msg3/Msg, RunSql/RunSql, ParseArgStd/ParseArgStd2
## 03-22-2018 @ 14:06:29 - 2.1.48 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
## 03-23-2018 @ 15:34:16 - 2.1.49 - dscudiero - D
## 03-23-2018 @ 16:18:45 - 2.1.50 - dscudiero - D
## 12-18-2018 @ 07:28:09 - 2.1.51 - dscudiero - Update setting of defaults to use the new toolsSetDefaults module
## 01-24-2019 @ 12:50:22 - 2.1.53 - dscudiero - Add encryption code
