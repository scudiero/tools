#=======================================================================================================================
# XO NOT AUTOVERSION
#=======================================================================================================================
version="2.2.4" # -- dscudiero -- Fri 06/28/2019 @ 07:26:36
#=======================================================================================================================
# Run every day at noon from cron
#=======================================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall StringFunctions"
Import "$standardIncludes $myIncludes"

originalArgStr="$*"

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
scriptArgs="$* -noBanners -batchMode"

#==================================================================================================
# Main
#==================================================================================================
case "$hostName" in
	mojave)
			RollupProcessLog
			;;
	build7)
		## Run programs/functions
			pgms=("\"escrowSites illinois -password illinois -outDir $courseleafEscrowedSitesDir -emaliList $escrowEmailAddrs\"")
			pgms+=("\"escrowSites uis -password uis -outDir $courseleafEscrowedSitesDir -emaliList $escrowEmailAddrs\"")
			pgms+=("\"escrowSites uic -password uic -outDir $courseleafEscrowedSitesDir -emaliList $escrowEmailAddrs\"")
			pgms+=("\"escrowSites ewu -password ewu -outDir $courseleafEscrowedSitesDir -emaliList $escrowEmailAddrs\"")

			for ((i=0; i<${#pgms[@]}; i++)); do
				pgm="${pgms[$i]}"; pgmName="${pgm%% *}"; pgmArgs="${pgm#* }"; [[ $pgmName == $pgmArgs ]] && unset pgmArgs
				Msg "\n$(date +"%m/%d@%H:%M") - Running $pgmName $pgmArgs..."; sTime=$(date "+%s")
				TrapSigs 'off'
				[[ ${pgm:0:1} == *[[:upper:]]* ]] && { $pgmName $pgmArgs | Indent; } || { FindExecutable $pgmName -sh -run $pgmArgs $scriptArgs | Indent; }
				TrapSigs 'on'
				Semaphore 'waiton' "$pgmName" 'true'
				Msg "...$pgmName done -- $(date +"%m/%d@%H:%M") ($(CalcElapsed $sTime))"
			done
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
## 06-18-2019 @ 07:14:32 - 2.2.1 - dscudiero - Cosmetic / Miscellaneous cleanup / Sync
## 06-25-2019 @ 08:49:23 - 2.2.2 - dscudiero -  Updated how escrowSites is called
## 06-27-2019 @ 08:20:27 - 2.2.3 - dscudiero -  Fix syntax error
## 06-28-2019 @ 07:26:50 - 2.2.4 - dscudiero -  fix bug parsing pgmArgs
