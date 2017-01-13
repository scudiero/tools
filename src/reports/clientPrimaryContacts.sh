#!/bin/bash
#XO NOT AUTOVERSION
#==================================================================================================
version=1.0.19 # -- dscudiero -- 01/12/2017 @ 14:13:09.22
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
function parseArgs-clientPrimaryContacts  { # or parseArgs-local
	argList+=(-reportName,6,option,reportName,,script,'The origional report name')
	argList+=(-emailAddrs,5,option,emailAddrs,,script,'Email addresses to send reports to when running in batch mode')
	return 0
}
function Goodbye-clientPrimaryContacts  { # or Goodbye-local
	rm -rf $tmpRoot > /dev/null 2>&1
	return 0
}
function testMode-clientPrimaryContacts  { # or testMode-local
	[[ $userName != 'dscudiero' ]] && Msg "T You do not have sufficient permissions to run this script in 'testMode'"
	return 0
}

#==================================================================================================
# local functions
#==================================================================================================

#==================================================================================================
# Declare local variables and constants
#==================================================================================================
tmpFile=$(mkTmpFile)
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
ParseArgsStd

[[ $reportName != '' ]] && GetDefaultsData "$reportName" "$reportsTable"
Hello

#===================================================================================================
# Main
#===================================================================================================
## Generate second report - folks in the contacts db that did not attend
	Msg2 "Generating Client Contact Report..."
	Msg2 >> $outFile; Msg2 >> $outFile; Msg2 >> $outFile
	Msg2 "Report: Client Contact Report" >> $outFile
	Msg2 "Date: $(date)" >> $outFile
	Msg2 >> $outFile
	echo -e "$header" >> $outFile

	cntr=0
	whereClause='clients.clientkey=contacts.clientkey and Lower(clients.is_active)="y" and contactrole like "Primary%"'
	orderBy="clients.clientcode,contactrole,contacts.lastname"
	sqlStmt="select $fields from clients,contacts where $whereClause order by $orderBy"

	RunSql2 "$contactsSqliteFile" "$sqlStmt"
	if [[ ${#resultSet[@]} -gt 0 ]]; then
		numRecs=${#resultSet[@]}
		Msg2 "^Found $numRecs contacts records..."
		for result in "${resultSet[@]}"; do
			if [[ $workBook != '' ]]; then
				longName=$(cut -d'|' -f3 <<< $result)
				firstName=$(cut -d'|' -f5 <<< $result)
				lastName=$(cut -d'|' -f6 <<< $result)
				key="$longName.$firstName.$lastName"
				[[ ${attendeeList["$key"]+abc} ]] && continue
			fi
			echo -e "$(tr '|' "\t" <<< "$result")" >> $outFile
			[[ $cntr -ne 0 && $(($cntr % 100)) -eq 0 ]] && Msg2 "^Processed $cntr out of $numRecs..."
			let cntr=$cntr+1
		done
	else
		Warning "Did not find any contacts records meeting criteria" | tee -a $outFile
	fi

	Msg2 >> $outFile
	Msg2
	Msg2 "Report output can be found in: '$outFile'"
	#[[ ${#clientSet[@]} -gt 0 ]] && sendMail=true

## Send email
	if [[ $emailAddrs != '' && $sendMail == true && batchMode == true ]]; then
		Msg2 >> $outFile; Msg2 "Sending email(s) to: $emailAddrs">> $outFile; Msg2 >> $outFile
		for emailAddr in $(echo $emailAddrs | tr ',' ' '); do
			mutt -a "$outFile" -s "$report report results: $(date +"%m-%d-%Y")" -- $emailAddr < $outFile
		done
	fi

#===================================================================================================
## Done
#===================================================================================================
[[ -f $tmpFile ]] && rm -f $tmpFile
[[ $batchMode == true && -f $outFile ]] && rm -f $outFileRoot*
Goodbye 0 #'alert'

#===================================================================================================
## Check-in log
#===================================================================================================



