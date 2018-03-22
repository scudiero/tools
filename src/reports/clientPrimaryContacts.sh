#!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.22 # -- dscudiero -- Thu 03/22/2018 @ 12:58:58.11
#==================================================================================================
Import GetDefaultsData ParseArgs ParseArgsStd Hello Init Goodbye
originalArgStr="$*"
scriptDescription=""

#= Description +===================================================================================
#
#
#==================================================================================================
#==================================================================================================
# Standard call back functions
#==================================================================================================
function clientPrimaryContacts-ParseArgsStd2  { # or parseArgs-local
	#myArgs+=("shortToken|longToken|type|scriptVariableName|<command to run>|help group|help textHelp")
	myArgs+=('email|emailAddrs|option|emailAddrs||script|Email addresses to send reports to when running in batch mode')
	myArgs+=('report|reportName|option|emailAdreportNamedrs||script|The origional report name')
	return 0
}
function clientPrimaryContacts-testMode  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
trueVars=''
falseVars=''
for var in $trueVars; do eval $var=true; done
for var in $falseVars; do eval $var=false; done

declare -A attendeeList
outDir=/home/$userName/Reports/$myName
[[ ! -d $outDir ]] && mkdir -p $outDir
outFileRoot="$outDir/$(date '+%Y-%m-%d-%H%M%S')"
outFile="${outFileRoot}${myName}.xls"

## Database fields & output header
header="Client Code\tLong Name\tHome URL\tCourseleaf Role\tFirst Name\tLast Name\tTitle\tWork phone\tCell phone\tFax Number\tEmail Address"
fields='clients.clientcode,clients.name,homeurl,contacts.contactrole,contacts.firstname,contacts.lastname'
fields="$fields,contacts.title,contacts.workphone,contacts.cell,contacts.fax,contacts.email"

#==================================================================================================
# Standard arg parsing and initialization
#==================================================================================================
ParseArgsStd2 $originalArgStr

[[ $reportName != '' ]] && GetDefaultsData "$reportName" "$reportsTable"
Hello

#===================================================================================================
# Main
#===================================================================================================
## Generate second report - folks in the contacts db that did not attend
	Msg "Generating Client Contact Report..."
	Msg >> $outFile; Msg >> $outFile; Msg >> $outFile
	Msg "Report: Client Contact Report" >> $outFile
	Msg "Date: $(date)" >> $outFile
	Msg >> $outFile
	echo -e "$header" >> $outFile

	cntr=0
	whereClause='clients.clientkey=contacts.clientkey and Lower(clients.is_active)="y" and contactrole like "Primary%"'
	orderBy="clients.clientcode,contactrole,contacts.lastname"
	sqlStmt="select $fields from clients,contacts where $whereClause order by $orderBy"

	RunSql "$contactsSqliteFile" "$sqlStmt"
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		numRecs=${#resultSet[@]}
		Msg "^Found $numRecs contacts records..."
		for result in "${resultSet[@]}"; do
			if [[ $workBook != '' ]]; then
				longName=$(cut -d'|' -f3 <<< $result)
				firstName=$(cut -d'|' -f5 <<< $result)
				lastName=$(cut -d'|' -f6 <<< $result)
				key="$longName.$firstName.$lastName"
				[[ ${attendeeList["$key"]+abc} ]] && continue
			fi
			echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
			[[ $cntr -ne 0 && $(($cntr % 100)) -eq 0 ]] && Msg "^Processed $cntr out of $numRecs..."
			let cntr=$cntr+1
		done
	else
		Warning "Did not find any contacts records meeting criteria" | tee -a $outFile
	fi

	Msg >> $outFile
	Msg
	Msg "Report output can be found in: '$outFile'"
	#[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Send email
	if [[ $emailAddrs != '' && $sendMail == true && batchMode == true ]]; then
		Msg >> $outFile; Msg "Sending email(s) to: $emailAddrs">> $outFile; Msg >> $outFile
		for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
			mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
		done
	fi

#===================================================================================================
## Done
#===================================================================================================
[[ $batchMode == true && -f $outFile ]] && rm -f $outFileRoot*
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================



## Mon Feb 13 16:09:30 CST 2017 - dscudiero - make sure we have our own tmpFile
## 03-22-2018 @ 13:02:53 - 1.0.22 - dscudiero - Updated for Msg3/Msg, RunSql2/RunSql, ParseArgStd/ParseArgStd2
