#!/bin/bash
#==================================================================================================
version=2.3.17 # -- dscudiero -- 01/23/2017 @ 12:26:22.35
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
Import "$includes"
originalArgStr="$*"
scriptDescription="Check for more than one client site is publishing"

#==================================================================================================
# Check to see if any two client sites are publishing to the same location
#==================================================================================================
# Copyright ©2015 David Scudiero -- all rights reserved.
# 09-10-14 -- dgs - Initial coding
# 07-17-15 -- dgs - Migrated to framework 5
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
sendMail=false

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
GetDefaultsData $myName
ParseArgsStd
Hello

#==================================================================================================
# Main loop
#==================================================================================================
unset dbRecs
sqlStmt="select name,publishing from $siteInfoTable where publishing <> \"/dev/null\" and publishing is not null  and publishing <> \"\" group by name,publishing having count(publishing) > 1"
RunSql2 $sqlStmt
[[ ${#resultSet[@]} -le 0 ]] && Goodbye 0
dbRecs=("${resultSet[@]}")
for dbRec in "${dbRecs[@]}"; do
	dbRec=$(echo $dbRec | tr "\t" "|"); dbRec=$(echo $dbRec | tr " " "|")
	client=$(echo $dbRec | cut -d "|" -f1)
	publishing=$(echo $dbRec | cut -d "|" -f2)
	sqlStmt="select distinct env from $siteInfoTable where name=\"$client\" and publishing=\"$publishing\";"
	RunSql2 $sqlStmt
	count=${#resultSet[@]}
	if [[ $count -ge  2 ]]; then
		IFSSave=$IFS; IFS=$','; envs=$(echo "${resultSet[*]}" | tr "\t" " "); IFS=$IFSSave
		Msg2 "^$client -- found multiple environments ($envs) publishing to the same locaton ($publishing)." | tee -a $tmpFile
		sendMail=true
	fi
done

#==================================================================================================
## Send out emails

if [[ $sendMail == true && $noEmails == false ]]; then
	Msg2 "\nEmails sent to: $emailAddrs\n" | tee -a $tmpFile
	mail -s "$myName found discrepancies" $emailAddrs < $tmpFile
fi

if [[ -f $tmpFile ]]; then
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	cat $tmpFile
	rm $tmpFile
fi

#==================================================================================================
## Bye-bye
#==================================================================================================
Goodbye 0
## Wed Apr 27 16:18:04 CDT 2016 - dscudiero - Switch to use RunSql
## Thu May 12 13:15:22 CDT 2016 - dscudiero - Fix problem where sites with publishing = were being picked up
## Mon Oct  3 07:06:17 CDT 2016 - dscudiero - Wrap clear statement with protection
## Mon Jan 23 12:26:59 CST 2017 - dscudiero - Fix problem using Msg not Msg2
