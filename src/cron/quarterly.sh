#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version=2.1.45 # -- dscudiero -- Wed 09/27/2017 @  7:32:59.54
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="SetSiteDirs ProtectedCall SetFileExpansion RunSql2"
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

 	Msg3 > $tmpFile
 	Msg3 $(date) >> $tmpFile
 	Msg3 >> $tmpFile
 	Msg3 "The following sites have been escrowed, the escrow files can be found at \n^'$courseleafEscrowedSitesDir'" >> $tmpFile

 	for client in $(tr ',' ' ' <<< $clientList); do
		Msg3 "^Processing client: $client" >> $tmpFile
		SetSiteDirs
		cd $(dirname $nextDir)
		[[ ! -d $tarDir ]] && mkdir $tarDir
		tarFile=$tarDir/$client@$(date +"%m-%d-%Y").tar.xz
		[[ -f $tarFile ]] && rm -f $tarFile

		Msg3 >> $tmpFile
		unset dirsToTar
		for env in test next curr public; do
			[[ -d ./$env ]] && dirsToTar="$env $dirsToTar"
		done
		dirsToTar=$(Trim "$dirsToTar")
		Msg3 "^^Tarring directories: $(echo $dirsToTar | tr ' ' ',')" >> $tmpFile

		set +f
		$DOIT tar -cJf $tarFile $dirsToTar; rc=$?
		rc=$?; [[ $rc -ne 0 ]] && Terminate "Process returned a non-zero return code ($rc), Please review messages"
		chgrp leepfrog $tarFile
		chmod 660 $tarFile
		Msg3 "^^Escrow file generated at: $tarFile" >> $tmpFile
	done

	## Send emails
		Msg3 >> $tmpFile
		if [[ $sendMail == true ]]; then
			Msg3 "\nEmails sent to: $escrowEmailAddrs\n" >> $tmpFile
			for emailAddr in $(tr ',' ' ' <<< $escrowEmailAddrs); do
				mail -s "$myName: Clients escrowed" $emailAddr < $tmpFile
			done
		fi

	[[ -f "$tmpFile" ]] && rm "$tmpFile"
	return 0
} #EscrowSite

function RollupProcessLog {
	## Roll up the weeks processlog db table
	Msg3 "\n*** Processlog rollup -- Starting ***"
	cd $TOOLSPATH/Logs
	outFile="$(date '+%m-%d-%y').processLog.xls"
	## Get the column names
	sqlStmt="select column_name from information_schema.columns where table_schema = \"$warehouseDb\" and table_name = \"$processLogTable\"";
	RunSql2 $sqlStmt
	resultString="${resultSet[@]}" ; resultString=$(tr " " "\t" <<< $resultString)
	echo "$resultString" >> $outFile
	SetFileExpansion 'off'
	sqlStmt="select * from $processLogTable"
	RunSql2 $sqlStmt
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
	RunSql2 $sqlStmt
	SetFileExpansion
	Msg3 "*** Processlog rollup -- Completed ***"
} #RollupProcessLog

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
			RollupProcessLog
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
return 0

#========================================================================================================================
# Change Log
#========================================================================================================================
## Thu Dec 29 16:50:40 CST 2016 - dscudiero - Updated the code to escrow sites to generalize
## Thu Jan  5 14:50:11 CST 2017 - dscudiero - Switch to use RunSql2
## Thu Feb  9 08:06:49 CST 2017 - dscudiero - make sure we are using our own tmpFile
## 07-17-2017 @ 07.52.31 - (2.1.33)    - dscudiero - Fix script syntax error on for statement
## 07-17-2017 @ 07.53.51 - (2.1.34)    - dscudiero - uncomment call to escrowClient
## 07-17-2017 @ 08.08.58 - (2.1.38)    - dscudiero - move escrowClient functionality into script
## 07-17-2017 @ 14.00.52 - (2.1.42)    - dscudiero - Many updates
## 09-21-2017 @ 10.02.41 - (2.1.43)    - dscudiero - Add rollup of the processlog
## 09-21-2017 @ 10.15.16 - (2.1.44)    - dscudiero - Change the name of the tar file to reflect the quarter number
## 09-27-2017 @ 07.52.12 - (2.1.45)    - dscudiero - Switched to msg3
