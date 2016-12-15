#!/bin/bash
#==================================================================================================
version=2.3.9 # -- dscudiero -- 12/14/2016 @ 11:19:32.14
#==================================================================================================
TrapSigs 'on'
includes='GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye'
Import "$includes"
originalArgStr="$*"
scriptDescription="Check for more than one client site is publishing"

#==================================================================================================
# Check to see if any two client sites are publishing to the same location
#==================================================================================================
# Copyright �2015 David Scudiero -- all rights reserved.
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
RunSql 'mysql' $sqlStmt
dbRecs=("${resultSet[@]}")
for dbRec in "${dbRecs[@]}"; do
	dbRec=$(echo $dbRec | tr "\t" "|"); dbRec=$(echo $dbRec | tr " " "|")
	client=$(echo $dbRec | cut -d "|" -f1)
	publishing=$(echo $dbRec | cut -d "|" -f2)
	sqlStmt="select distinct env from $siteInfoTable where name=\"$client\" and publishing=\"$publishing\";"
	RunSql 'mysql' $sqlStmt
	count=${#resultSet[@]}
	if [[ $count -ge  2 ]]; then
		IFSSave=$IFS; IFS=$','; envs=$(echo "${resultSet[*]}" | tr "\t" " "); IFS=$IFSSave
		Msg "\t$client -- found multiple environments ($envs) publishing to the same locaton ($publishing)." | tee -a $tmpFile
		sendMail=true
	fi
done

#==================================================================================================
## Send out emails
if [[ $sendMail == true && $noEmails == false ]]; then
	Msg "\nEmails sent to: $emailAddrs\n" | tee -a $tmpFile
	mail -s "$myName found discrepencies" $emailAddrs < $tmpFile
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
