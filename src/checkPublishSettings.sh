#!/bin/bash
#==================================================================================================
version=2.3.23 # -- dscudiero -- Thu 03/22/2018 @ 12:27:43.40
#==================================================================================================
TrapSigs 'on'
myIncludes="ProtectedCall StringFunctions RunSql"
Import "$standardInteractiveIncludes $myIncludes"

originalArgStr="$*"
scriptDescription="Check for more than one client site is publishing to the same location"

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
Hello
GetDefaultsData $myName
ParseArgsStd2 $originalArgStr
tmpFile=$(MkTmpFile)

#==================================================================================================
# Main loop
#==================================================================================================
unset dbRecs
sqlStmt="select name,publishing from $siteInfoTable where publishing <> \"/dev/null\" and publishing is not null  and publishing <> \"\" group by name,publishing having count(publishing) > 1"
RunSql $sqlStmt
[[ ${#resultSet[@]} -le 0 ]] && Goodbye 0
dbRecs=("${resultSet[@]}")
for dbRec in "${dbRecs[@]}"; do
	dbRec=$(echo $dbRec | tr "\t" "|"); dbRec=$(echo $dbRec | tr " " "|")
	client=$(echo $dbRec | cut -d "|" -f1)
	publishing=$(echo $dbRec | cut -d "|" -f2)
	sqlStmt="select distinct env from $siteInfoTable where name=\"$client\" and publishing=\"$publishing\";"
	RunSql $sqlStmt
	count=${#resultSet[@]}
	if [[ $count -ge  2 ]]; then
		IFSSave=$IFS; IFS=$','; envs=$(echo "${resultSet[*]}" | tr "\t" " "); IFS=$IFSSave
		Msg "^$client -- found multiple environments ($envs) publishing to the same locaton ($publishing)." | tee -a $tmpFile
		sendMail=true
	fi
done

#==================================================================================================
## Send out emails

if [[ $sendMail == true && $noEmails == false ]]; then
	Msg "\nEmails sent to: $emailAddrs\n" | tee -a $tmpFile
	Msg "\n*** Please do not respond to this email, it was sent by an automated process\n" >> $tmpFile
	mail -s "$myName found discrepancies" $emailAddrs < $tmpFile
fi

if [[ -f $tmpFile ]]; then
	[[ $batchMode != true && $noClear != true && $TERM != 'dumb' ]] && clear
	cat $tmpFile
	rm $tmpFile
fi

[[ -f "$tmpFile" ]] && rm "$tmpFile"

#==================================================================================================
## Bye-bye
#==================================================================================================
Goodbye 0
## Wed Apr 27 16:18:04 CDT 2016 - dscudiero - Switch to use RunSql
## Thu May 12 13:15:22 CDT 2016 - dscudiero - Fix problem where sites with publishing = were being picked up
## Mon Oct  3 07:06:17 CDT 2016 - dscudiero - Wrap clear statement with protection
## Mon Jan 23 12:26:59 CST 2017 - dscudiero - Fix problem using Msg not Msg
## Mon Feb 13 15:59:27 CST 2017 - dscudiero - Make sure we are using our own tmpFile
## 10-23-2017 @ 07.36.07 - (2.3.21)    - dscudiero - Tweak messaging
## 03-22-2018 @ 12:35:39 - 2.3.23 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
